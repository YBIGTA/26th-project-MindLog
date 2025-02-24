import json
import os
import numpy as np
import cv2
from deepface import DeepFace
from scipy.spatial.distance import cosine
from scipy.cluster.hierarchy import fcluster, linkage
from typing import Dict, List
from PIL import Image
import tempfile
import tensorflow as tf

# Metal 플러그인 활성화 시도
try:
    tf.config.experimental.set_visible_devices([], 'GPU')
    print("✅ TensorFlow Metal 플러그인 활성화됨")
except:
    print("⚠️ TensorFlow Metal 플러그인 활성화 실패")

# ✅ 현재 파일(companion_tag.py)의 경로를 기준으로 `data/face_database.json` 절대 경로 설정
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # ai-server 경로
DATABASE_PATH = os.path.join(BASE_DIR, "data", "face_database.json")  # ai-server/data/face_database.json

class CompanionTagger:
    def __init__(self):
        """🔹 AI 서버 내부 저장된 얼굴 데이터베이스 로드"""
        self.face_database = self.load_database()

    def load_database(self):
        """🔹 AI 서버 내부 얼굴 데이터베이스 로드"""
        if os.path.exists(DATABASE_PATH):
            with open(DATABASE_PATH, "r", encoding="utf-8") as f:
                try:
                    return json.load(f)
                except json.JSONDecodeError:
                    print("⚠️ 데이터베이스 JSON 로드 실패 → 초기화 진행")
                    return {}  # JSON 오류 발생 시 초기화
        return {}

    def save_database(self, database):
        """🔹 AI 서버 내부 얼굴 데이터베이스 저장"""
        # person_id를 숫자 기준으로 정렬
        sorted_database = {}
        person_ids = sorted(database.keys(), key=lambda x: int(x.split('_')[1]))
        
        # 1번부터 순차적으로 재할당
        for new_id, old_id in enumerate(person_ids, 1):
            sorted_database[f"person_{new_id}"] = database[old_id]
        
        # 정렬된 데이터베이스 저장
        os.makedirs(os.path.dirname(DATABASE_PATH), exist_ok=True)
        with open(DATABASE_PATH, "w", encoding="utf-8") as f:
            json.dump(sorted_database, f, ensure_ascii=False, indent=4)

    def get_face_embeddings(self, image_data_dict: Dict[str, Image.Image]):
        """🔹 이미지에서 얼굴 검출 및 임베딩 추출"""
        face_data = []
        
        for url, img in image_data_dict.items():
            try:
                if not isinstance(img, Image.Image):
                    continue
                
                # 이미지 전처리
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                
                print(f"🔍 이미지 정보: {url}")
                print(f"- 크기: {img.size}")
                print(f"- 모드: {img.mode}")
                print(f"- 형식: {img.format}")
                
                with tempfile.NamedTemporaryFile(suffix='.jpg') as temp:
                    img.save(temp.name, 'JPEG', quality=95)
                    
                    try:
                        # 얼굴 검출 - detector_kwargs 제거
                        faces = DeepFace.extract_faces(
                            img_path=temp.name,
                            detector_backend='retinaface',
                            enforce_detection=True,
                            align=True
                        )
                        
                        if not faces:
                            print(f"⚠️ 얼굴 검출 실패: {url}")
                            continue
                        
                        print(f"🔍 검출된 얼굴 수: {len(faces)}")
                        
                        # 임베딩 추출 - enforce_detection=True로 변경
                        embeddings = DeepFace.represent(
                            img_path=temp.name,
                            model_name="Facenet",
                            enforce_detection=True,  # False → True
                            detector_backend='retinaface'
                        )
                        
                        if not isinstance(embeddings, list):
                            embeddings = [embeddings]
                        
                        for i, embedding in enumerate(embeddings):
                            if isinstance(embedding, dict) and 'embedding' in embedding:
                                embedding_array = np.array(embedding['embedding'])
                            else:
                                embedding_array = np.array(embedding)
                            
                            if embedding_array.shape == (128,):
                                face_data.append((url, embedding_array))
                                print(f"✅ 얼굴 {i+1} 임베딩 추출 완료: {url}")
                
                    except Exception as e:
                        print(f"⚠️ 얼굴 검출/임베딩 추출 실패: {url}, 오류: {str(e)}")
                        continue
                    
            except Exception as e:
                print(f"⚠️ 이미지 처리 실패: {url}, 오류: {str(e)}")
                continue
        
        return face_data

    def cluster_faces_hierarchical(self, face_data, threshold=0.7):
        """🔹 배치 내 얼굴 클러스터링"""
        if not face_data:
            return {}
        
        embeddings = np.array([data[1] for data in face_data if data[1] is not None])
        
        if len(embeddings) < 2:
            return {data[0]: ["person_1"] for data in face_data}

        # 유사도 행렬 계산 (코사인 거리 대신 1 - 코사인 유사도 사용)
        similarity_matrix = np.zeros((len(embeddings), len(embeddings)))
        for i in range(len(embeddings)):
            for j in range(i + 1, len(embeddings)):
                similarity = 1 - cosine(embeddings[i], embeddings[j])
                similarity_matrix[i][j] = 1 - similarity  # 유사도를 거리로 변환
                similarity_matrix[j][i] = 1 - similarity

        # 계층적 클러스터링 수행
        linkage_matrix = linkage(similarity_matrix, method='complete')
        clusters = fcluster(linkage_matrix, 1 - threshold, criterion='distance')  # threshold 기준 반전
        
        # 결과 매핑
        result = {url: [] for url, _ in face_data}
        for i, cluster_id in enumerate(clusters):
            url = face_data[i][0]
            result[url].append(f"person_{cluster_id}")
            print(f"🔍 {url} → 클러스터 {cluster_id} (유사도: {1 - similarity_matrix[i][i-1]:.3f})")
        
        return result

    def match_with_database(self, assigned_tags, face_data, threshold=0.6):
        '''클러스터링된 얼굴을 DB와 매칭'''
        result = {}
        
        # 데이터베이스 로드
        database = self.load_database()
        
        for image_url in assigned_tags.keys():
            result[image_url] = []
            
            # 이미지에서 검출된 얼굴들의 임베딩 찾기
            image_embeddings = [emb for url, emb in face_data if url == image_url]
            print(f"- 이미지 {image_url}의 임베딩 개수: {len(image_embeddings)}")
            
            # DB가 비어있거나 방금 생성된 경우, 클러스터링 결과 사용
            if not database or len(database) == len(image_embeddings):
                result[image_url] = assigned_tags[image_url]
                print(f"✅ 새로운 인물 태그 생성: {assigned_tags[image_url]}")
                continue
            
            # 각 얼굴 임베딩에 대해 기존 DB와 매칭
            for embedding in image_embeddings:
                matched_person = None
                max_similarity = -1
                
                # DB의 각 인물과 비교
                for person_id, person_data in database.items():
                    for db_data in person_data["embeddings"]:
                        db_embedding = db_data["embedding"]
                        similarity = 1 - cosine(embedding, db_embedding)
                        if similarity > max_similarity and similarity >= threshold:
                            max_similarity = similarity
                            matched_person = person_id
                
                # 매칭된 인물이 있으면 결과에 추가
                if matched_person:
                    if matched_person not in result[image_url]:  # 중복 방지
                        result[image_url].append(matched_person)
                        print(f"✅ 매칭된 인물 추가: {image_url} → {matched_person} (유사도: {max_similarity:.3f})")
                else:
                    print(f"⚠️ 매칭된 인물 없음: 최대 유사도 {max_similarity:.3f}")
        
        return result

    def process_faces(self, image_data_dict: Dict[str, Image.Image]):
        """🔹 인물 태깅 실행 함수 (여러 얼굴 처리)"""
        face_dir = "data/faces"
        os.makedirs(face_dir, exist_ok=True)
        
        # 얼굴 검출 및 임베딩 추출
        face_data = self.get_face_embeddings(image_data_dict)
        face_images = self.get_face_images(image_data_dict)
        print(f"🔍 검출된 얼굴 데이터: {len(face_data)}개")
        
        # 얼굴이 검출되지 않은 경우 빈 결과 반환
        if not face_data:
            print("⚠️ 검출된 얼굴 없음")
            return {url: [] for url in image_data_dict.keys()}
        
        # 1. 배치 내 얼굴 클러스터링 수행
        batch_clusters = self.cluster_faces_hierarchical(face_data, threshold=0.7)
        print(f"✅ 배치 내 클러스터링 완료: {len(batch_clusters)}개 이미지")
        
        # 2. DB 로드 및 매칭
        database = self.load_database()
        if not database:
            print("✅ DB 없음 → 클러스터링 결과로 새 DB 생성")
            
            # 클러스터별 얼굴 매핑 및 임베딩 매핑
            cluster_faces = {}
            cluster_embeddings = {}  # 클러스터별 임베딩 저장
            
            # 얼굴과 임베딩을 클러스터별로 매핑
            for url, faces in face_images.items():
                clusters = batch_clusters[url]
                # 해당 URL의 임베딩 찾기
                url_embeddings = [emb for f_url, emb in face_data if f_url == url]
                
                for i, (face, cluster_id, embedding) in enumerate(zip(faces, clusters, url_embeddings)):
                    person_id = f"person_{cluster_id.split('_')[1]}"
                    
                    # 얼굴 이미지 저장 (처음 한 번만)
                    if person_id not in cluster_faces:
                        cluster_faces[person_id] = face
                        face_path = os.path.join(face_dir, f"{person_id}.jpg")
                        face.save(face_path)
                        print(f"✅ 얼굴 이미지 저장: {face_path}")
                    
                    # 임베딩 매핑
                    if person_id not in cluster_embeddings:
                        cluster_embeddings[person_id] = []
                    cluster_embeddings[person_id].append({
                        "url": url,
                        "embedding": embedding.tolist()
                    })
            
            # DB 생성
            for person_id, embeddings in cluster_embeddings.items():
                database[person_id] = {
                    "embeddings": embeddings
                }
                print(f"✅ {person_id}의 임베딩 {len(embeddings)}개 저장")
            self.save_database(database)
            return batch_clusters
        
        # 3. 기존 DB가 있는 경우, 각 클러스터와 DB 매칭
        print("✅ 기존 DB와 매칭 시도")
        final_results = {url: [] for url in image_data_dict.keys()}
        db_updates = {}  # DB 업데이트를 위한 임시 저장소
        
        face_idx = {}
        for url in image_data_dict.keys():
            face_idx[url] = 0
        
        for url, cluster_ids in batch_clusters.items():
            for cluster_id in cluster_ids:
                # 해당 클러스터의 대표 임베딩 찾기
                cluster_embedding = None
                current_face_idx = face_idx[url]
                for i, (face_url, embedding) in enumerate(face_data):
                    if face_url == url and i == current_face_idx:  # 현재 처리 중인 얼굴의 임베딩을 정확히 찾음
                        cluster_embedding = embedding
                        break
                
                if cluster_embedding is None:
                    continue
                
                # DB의 각 인물과 비교
                best_match = None
                max_similarity = -1
                
                for person_id, person_data in database.items():
                    for db_data in person_data["embeddings"]:
                        similarity = 1 - cosine(cluster_embedding, np.array(db_data["embedding"]))
                        print(f"- 유사도 체크: {cluster_id} vs {person_id} → {similarity:.3f}")
                        if similarity > max_similarity:
                            max_similarity = similarity
                            if similarity >= 0.55:  # 0.6 → 0.55로 임계값 낮춤
                                best_match = person_id
                            print(f"  → max_similarity 갱신: {similarity:.3f}")
                            if best_match:
                                print(f"  → best_match 갱신: {best_match}")
                
                print(f"최종 best_match: {best_match}, max_similarity: {max_similarity:.3f}")

                if best_match:
                    print(f"✅ if best_match 조건문 진입")
                    # DB의 기존 인물과 매칭된 경우
                    print(f"✅ 클러스터 {cluster_id} → DB의 {best_match}와 매칭 (유사도: {max_similarity:.3f})")
                    if best_match not in final_results[url]:
                        final_results[url].append(best_match)
                    # 새 임베딩 임시 저장
                    if best_match not in db_updates:
                        db_updates[best_match] = []
                    db_updates[best_match].append({
                        "url": url,
                        "embedding": cluster_embedding.tolist()
                    })
                    face_idx[url] += 1
                else:
                    print(f"❌ best_match가 None이어서 새 인물 추가")
                    # 새로운 인물로 추가
                    next_id = max([int(pid.split('_')[1]) for pid in list(database.keys()) + list(db_updates.keys())]) + 1
                    new_person_id = f"person_{next_id}"
                    print(f"✅ 새로운 인물 추가: {new_person_id}")
                    
                    # 새 인물의 얼굴 이미지 저장
                    if url in face_images:
                        face_path = os.path.join(face_dir, f"{new_person_id}.jpg")
                        face_img = face_images[url][face_idx[url]]
                        face_img.save(face_path)
                        print(f"✅ 얼굴 이미지 저장: {face_path}")

                    if new_person_id not in db_updates:
                        db_updates[new_person_id] = []
                    db_updates[new_person_id].append({
                        "url": url,
                        "embedding": cluster_embedding.tolist()
                    })
                    face_idx[url] += 1
                    final_results[url].append(new_person_id)
        
        # 모든 매칭이 끝난 후 DB 업데이트
        if db_updates:
            for person_id, embeddings in db_updates.items():
                if person_id in database:
                    database[person_id]["embeddings"].extend(embeddings)
                else:
                    database[person_id] = {"embeddings": embeddings}
            self.save_database(database)
            print("✅ DB 저장 완료")
        
        # 결과 반환 전에 인물 태그 정렬
        for url in final_results:
            final_results[url] = sorted(final_results[url], key=lambda x: int(x.split('_')[1]))
        
        return final_results

    def get_face_images(self, image_data_dict: Dict[str, Image.Image]):
        """🔹 얼굴 이미지 추출"""
        face_images = {}
        
        for url, img in image_data_dict.items():
            try:
                if not isinstance(img, Image.Image):
                    continue
                
                # 이미지 전처리
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                
                with tempfile.NamedTemporaryFile(suffix='.jpg') as temp:
                    img.save(temp.name, 'JPEG', quality=95)
                    
                    # 얼굴 검출
                    try:
                        faces = DeepFace.extract_faces(
                            img_path=temp.name,
                            detector_backend='retinaface',
                            enforce_detection=True,  # 얼굴 검출 강제
                            align=True
                        )
                        
                        # 얼굴이 검출된 경우에만 처리
                        if faces and len(faces) > 0:
                            face_images[url] = []
                            for face in faces:
                                if 'face' in face and face['face'] is not None:
                                    face_array = face['face']
                                    if isinstance(face_array, np.ndarray):
                                        if face_array.dtype != np.uint8:
                                            face_array = (face_array * 255).astype(np.uint8)
                                        if len(face_array.shape) == 2:
                                            face_array = cv2.cvtColor(face_array, cv2.COLOR_GRAY2RGB)
                                        elif face_array.shape[-1] == 4:
                                            face_array = cv2.cvtColor(face_array, cv2.COLOR_RGBA2RGB)
                                        
                                        face_img = Image.fromarray(face_array)
                                        face_img = face_img.resize((224, 224), Image.Resampling.LANCZOS)
                                        face_images[url].append(face_img)
                                        print(f"✅ 얼굴 이미지 추출 성공: {url} (얼굴 {len(face_images[url])})")
                        else:
                            print(f"⚠️ 얼굴 검출 실패: {url}")
                    
                    except Exception as e:
                        print(f"⚠️ 얼굴 검출 실패: {url}, 오류: {str(e)}")
                        continue
            
            except Exception as e:
                print(f"⚠️ 얼굴 이미지 추출 실패: {url}, 오류: {str(e)}")
                continue
        
        return face_images