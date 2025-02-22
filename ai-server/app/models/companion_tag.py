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

    def save_database(self):
        """🔹 AI 서버 내부 얼굴 데이터베이스 저장"""
        os.makedirs(os.path.dirname(DATABASE_PATH), exist_ok=True)  # ✅ data 폴더 자동 생성
        with open(DATABASE_PATH, "w", encoding="utf-8") as f:
            json.dump(self.face_database, f, ensure_ascii=False, indent=4)

    def get_face_embeddings(self, image_data_dict: Dict[str, Image.Image], confidence_threshold=0.9, min_face_size=30):
        """🔹 PIL 이미지 객체를 통해 얼굴 검출 및 임베딩 추출"""
        face_data = []
        for image_url, image in image_data_dict.items():
            try:
                if image is None:
                    continue  # 이미지가 없으면 건너뜀

                # ✅ 이미지 임시 저장 (DeepFace는 로컬 파일 필요)
                temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
                image.save(temp_file.name, format="JPEG")

                detected_faces = DeepFace.extract_faces(img_path=temp_file.name, detector_backend="mtcnn")
                filtered_faces = [
                    face for face in detected_faces
                    if face.get("confidence", 0) >= confidence_threshold
                    and face["face"].shape[0] > min_face_size
                ]

                if not filtered_faces:
                    print(f"⚠️ {image_url} → 얼굴 검출 실패 (인물 태그 없음)")
                    continue

                for face in filtered_faces:
                    try:
                        emb = DeepFace.represent(img_path=temp_file.name, model_name="Facenet", enforce_detection=False)
                        if emb:
                            face_embedding = np.array(emb[0]['embedding'])
                            face_data.append((image_url, face_embedding))  # ✅ face_array 제거됨
                    except Exception as e:
                        print(f"⚠️ 얼굴 임베딩 실패: {e}")

                # ✅ 처리 완료 후 임시 파일 삭제
                os.remove(temp_file.name)

            except Exception as e:
                print(f"❌ 얼굴 검출 실패: {image_url}, 오류: {e}")

        return face_data

    def cluster_faces_hierarchical(self, face_data, threshold=0.6):
        """🔹 배치 내 얼굴 클러스터링"""
        embeddings = np.array([data[1] for data in face_data if data[1] is not None])

        if len(embeddings) < 2:
            return {data[0]: "person_1" for data in face_data}

        linkage_matrix = linkage(embeddings, method="ward")
        clusters = fcluster(linkage_matrix, threshold, criterion="distance")

        assigned_tags = {}
        for i, cluster_id in enumerate(clusters):
            assigned_tags[face_data[i][0]] = f"person_{cluster_id}"
            print(f"🔍 {face_data[i][0]} → 클러스터 {cluster_id}")

        return assigned_tags

    def match_with_database(self, assigned_tags, face_data, threshold=0.7):
        """🔹 기존 DB와 비교하여 최종 인물 태깅"""
        updated_tags = {}

        next_person_id = len(self.face_database) + 1

        for img_path, embedding in face_data:
            if embedding is None:
                continue

            best_match = None
            best_similarity = 0

            for person_id, data in self.face_database.items():
                for existing_embedding in data.get("embeddings", []):
                    similarity = 1 - cosine(embedding, existing_embedding)
                    if similarity >= threshold and similarity > best_similarity:
                        best_similarity = similarity
                        best_match = person_id

            if best_match:
                person_tag = best_match  # ✅ 변환 없이 person_X 문자열 반환
                self.face_database[best_match]["embeddings"].append(embedding.tolist())
                self.face_database[best_match]["image_paths"].append(img_path)
            else:
                new_person_tag = f"person_{next_person_id}"
                person_tag = new_person_tag  # ✅ 변환 없이 person_X 문자열 반환
                self.face_database[new_person_tag] = {
                    "embeddings": [embedding.tolist()],
                    "image_paths": [img_path],
                }
                next_person_id += 1

            updated_tags[img_path] = person_tag  # ✅ JSON 변환 없이 문자열 반환

        self.save_database()  # ✅ 업데이트된 데이터베이스 저장
        return updated_tags

    def process_faces(self, image_data_dict: Dict[str, Image.Image]):
        """🔹 인물 태깅 실행 함수 (여러 얼굴 처리)"""
        face_data = self.get_face_embeddings(image_data_dict)
        batch_tags = self.cluster_faces_hierarchical(face_data)
        final_tags = self.match_with_database(batch_tags, face_data)

        # ✅ 하나의 이미지에서 여러 인물 태깅 가능하도록 리스트 반환
        result = {}
        for image_url, person in final_tags.items():
            if image_url not in result:
                result[image_url] = []
            result[image_url].append(person)  # ✅ 리스트에 추가

        return result