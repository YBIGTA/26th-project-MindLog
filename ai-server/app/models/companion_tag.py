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
        os.makedirs(os.path.dirname(DATABASE_PATH), exist_ok=True)  # ✅ data 폴더 자동 생성
        with open(DATABASE_PATH, "w", encoding="utf-8") as f:
            json.dump(database, f, ensure_ascii=False, indent=4)

    def get_face_embeddings(self, image_data_dict: Dict[str, Image.Image]):
        """🔹 이미지에서 얼굴 검출 및 임베딩 추출"""
        face_data = []
        
        for url, img in image_data_dict.items():
            try:
                if not isinstance(img, Image.Image):
                    print(f"⚠️ 잘못된 이미지 형식: {type(img)}")
                    continue
                
                # 이미지 모드 확인 및 변환
                if img.mode != 'RGB':
                    img = img.convert('RGB')
                
                print(f"🔍 이미지 정보: {url}")
                print(f"- 크기: {img.size}")
                print(f"- 모드: {img.mode}")
                print(f"- 형식: {img.format}")
                
                # 전체 이미지에서 직접 임베딩 추출 시도
                with tempfile.NamedTemporaryFile(suffix='.jpg') as temp:
                    img.save(temp.name, 'JPEG', quality=95)
                    
                    try:
                        # 먼저 얼굴 검출
                        faces = DeepFace.extract_faces(
                            img_path=temp.name,
                            detector_backend='retinaface',
                            enforce_detection=False
                        )
                        
                        print(f"🔍 검출된 얼굴 수: {len(faces)}")
                        
                        # 전체 이미지에서 임베딩 추출
                        embeddings = DeepFace.represent(
                            img_path=temp.name,
                            model_name="Facenet",
                            enforce_detection=False,
                            detector_backend='retinaface'
                        )
                        
                        # embeddings가 리스트가 아니면 리스트로 변환
                        if not isinstance(embeddings, list):
                            embeddings = [embeddings]
                        
                        print(f"🔍 추출된 임베딩 수: {len(embeddings)}")
                        
                        # 각 임베딩 처리
                        for i, embedding in enumerate(embeddings):
                            if isinstance(embedding, dict) and 'embedding' in embedding:
                                embedding_array = np.array(embedding['embedding'])
                            else:
                                embedding_array = np.array(embedding)
                            
                            print(f"🔍 임베딩 {i+1} shape: {embedding_array.shape}")
                            
                            if embedding_array.shape == (128,):  # 올바른 shape 확인
                                face_data.append((url, embedding_array))
                                print(f"✅ 얼굴 {i+1} 임베딩 추출 완료: {url}")
                            else:
                                print(f"⚠️ 잘못된 임베딩 shape: {embedding_array.shape}")
                        
                    except Exception as e:
                        print(f"⚠️ 얼굴 검출/임베딩 추출 실패: {url}, 오류: {str(e)}")
                        continue
                    
            except Exception as e:
                print(f"⚠️ 이미지 처리 실패: {url}, 오류: {str(e)}")
                continue
        
        return face_data

    def cluster_faces_hierarchical(self, face_data, threshold=0.4):
        """🔹 배치 내 얼굴 클러스터링"""
        if not face_data:
            return {}
        
        embeddings = np.array([data[1] for data in face_data if data[1] is not None])
        
        if len(embeddings) < 2:
            return {data[0]: ["person_1"] for data in face_data}  # 리스트로 변경

        # 얼굴 임베딩 간의 거리 행렬 계산
        distance_matrix = np.zeros((len(embeddings), len(embeddings)))
        for i in range(len(embeddings)):
            for j in range(i + 1, len(embeddings)):
                distance = cosine(embeddings[i], embeddings[j])
                distance_matrix[i][j] = distance
                distance_matrix[j][i] = distance

        # 계층적 클러스터링 수행
        linkage_matrix = linkage(distance_matrix, method='complete')
        clusters = fcluster(linkage_matrix, threshold, criterion='distance')

        assigned_tags = {}
        for i, cluster_id in enumerate(clusters):
            url = face_data[i][0]
            if url not in assigned_tags:
                assigned_tags[url] = []
            assigned_tags[url].append(f"person_{cluster_id}")
            print(f"🔍 {url} → 클러스터 {cluster_id} (거리: {distance_matrix[i].mean():.3f})")

        return assigned_tags

    """
    def match_with_database(self, assigned_tags, face_data, threshold=0.8):
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
    """

    def process_faces(self, image_data_dict: Dict[str, Image.Image]):
        """🔹 인물 태깅 실행 함수 (여러 얼굴 처리)"""
        # 얼굴 검출 및 임베딩 추출
        face_data = self.get_face_embeddings(image_data_dict)
        print(f"🔍 검출된 얼굴 데이터: {len(face_data)}개")
        
        # 얼굴이 검출되지 않은 경우 빈 결과 반환
        if not face_data:
            print("⚠️ 검출된 얼굴 없음")
            return {url: [] for url in image_data_dict.keys()}
        
        # DB 로드
        database = self.load_database()
        if not database:
            print("✅ 새로운 DB 생성")
            database = {}
        
        # 결과 초기화
        result = {url: [] for url in image_data_dict.keys()}
        db_updated = False
        
        # 각 얼굴에 대해 처리
        for url, embedding in face_data:
            try:
                # 임베딩 데이터 형식 확인 및 변환
                if isinstance(embedding, dict) and 'embedding' in embedding:
                    embedding = np.array(embedding['embedding'])
                elif not isinstance(embedding, np.ndarray):
                    embedding = np.array(embedding)
                
                if embedding.shape != (128,):
                    print(f"⚠️ 잘못된 임베딩 형식: {embedding.shape}")
                    continue
                
                matched = False
                max_similarity = -1
                best_match = None
                
                # 기존 DB와 매칭 시도
                if database:
                    for person_id, person_data in database.items():
                        for db_data in person_data["embeddings"]:
                            db_embedding = np.array(db_data["embedding"])
                            similarity = 1 - cosine(embedding, db_embedding)
                            print(f"- 유사도 체크: {person_id} → {similarity:.3f}")
                            if similarity > max_similarity and similarity >= 0.5:
                                max_similarity = similarity
                                best_match = person_id
                                matched = True
                
                if matched:
                    # 기존 인물과 매칭된 경우
                    print(f"✅ 기존 인물과 매칭: {best_match} (유사도: {max_similarity:.3f})")
                    if best_match not in result[url]:
                        result[url].append(best_match)
                    
                    # 새로운 임베딩 추가
                    database[best_match]["embeddings"].append({
                        "url": url,
                        "embedding": embedding.tolist()
                    })
                    db_updated = True
                    print(f"✅ 새로운 임베딩 추가: {best_match}")
                    
                else:
                    # 새로운 인물인 경우
                    next_id = 1
                    if database:
                        existing_ids = [int(person_id.split('_')[1]) for person_id in database.keys()]
                        next_id = max(existing_ids) + 1
                    
                    new_person_id = f"person_{next_id}"
                    print(f"✅ 새로운 인물 추가: {new_person_id}")
                    
                    database[new_person_id] = {
                        "embeddings": [{
                            "url": url,
                            "embedding": embedding.tolist()
                        }]
                    }
                    result[url].append(new_person_id)
                    db_updated = True
            
            except Exception as e:
                print(f"⚠️ 얼굴 처리 실패: {url}, 오류: {str(e)}")
                continue
        
        # DB 저장 (변경된 경우에만)
        if db_updated:
            self.save_database(database)
            print("✅ DB 저장 완료")
        
        return result