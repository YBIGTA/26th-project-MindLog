import numpy as np
import cv2
import os
import requests
from deepface import DeepFace
from scipy.spatial.distance import cosine
from scipy.cluster.hierarchy import fcluster, linkage
from typing import Dict, List
import matplotlib.pyplot as plt

class CompanionTagger:
    def __init__(self, face_database: dict = None):
        # 얼굴 데이터베이스를 JSON 형식으로 받음
        self.face_database = face_database or {}

        # ✅ 영어 경로를 가진 임시 폴더 사용
        self.temp_dir = r"/tmp"
        if not os.path.exists(self.temp_dir):
            os.makedirs(self.temp_dir)

    def get_face_embeddings(self, image_urls: List[str], confidence_threshold=0.9, min_face_size=30):
        """ URL을 통해 얼굴 검출 및 임베딩 추출 """
        face_data = []
        for image_url in image_urls:
            try:
                response = requests.get(image_url)
                image_data = np.frombuffer(response.content, np.uint8)
                image = cv2.imdecode(image_data, cv2.IMREAD_COLOR)

                detected_faces = DeepFace.extract_faces(img_path=image_url, detector_backend="mtcnn")
                filtered_faces = [
                    face for face in detected_faces
                    if face.get("confidence", 0) >= confidence_threshold
                    and face["face"].shape[0] > min_face_size
                ]

                if not filtered_faces:
                    print(f"⚠️ {image_url} → 얼굴 검출 실패 (인물 태그 없음)")
                    continue

                for face in filtered_faces:
                    face_array = np.array(face["face"] * 255, dtype=np.uint8)
                    temp_face_path = os.path.join(self.temp_dir, "temp_embedding.jpg")
                    cv2.imwrite(temp_face_path, face_array)

                    try:
                        emb = DeepFace.represent(img_path=temp_face_path, model_name="Facenet", enforce_detection=False)
                        if emb:
                            face_embedding = np.array(emb[0]['embedding'])
                            face_data.append((image_url, face_embedding, face_array))
                    except Exception as e:
                        print(f"⚠️ 얼굴 임베딩 실패: {e}")
            except Exception as e:
                print(f"❌ 얼굴 검출 실패: {image_url}, 오류: {e}")

        return face_data

    def cluster_faces_hierarchical(self, face_data, threshold=0.7):
        """ 배치 내 얼굴 클러스터링 """
        embeddings = np.array([data[1] for data in face_data if data[1] is not None])
        
        if len(embeddings) < 2:
            return {data[0]: "person_1" for data in face_data}
        
        linkage_matrix = linkage(embeddings, method="ward")
        clusters = fcluster(linkage_matrix, threshold, criterion="distance")
        
        assigned_tags = {}
        for i, cluster_id in enumerate(clusters):
            assigned_tags[face_data[i][0]] = f"person_{cluster_id}"
        
        return assigned_tags
    
    def match_with_database(self, assigned_tags, face_data, threshold=0.7):
        """ 기존 DB와 비교하여 최종 인물 태깅 """
        updated_tags = assigned_tags.copy()
        next_person_id = len(self.face_database) + 1

        for img_path, embedding, face_img in face_data:
            if embedding is None:
                continue  # 얼굴 검출 실패한 경우 제외

            best_match = None
            best_similarity = 0

            for person_id, data in self.face_database.items():
                for existing_embedding in data.get("embeddings", []):
                    similarity = 1 - cosine(embedding, existing_embedding)
                    if similarity >= threshold and similarity > best_similarity:
                        best_similarity = similarity
                        best_match = person_id

            if best_match:
                updated_tags[img_path] = best_match
                self.face_database[best_match]["embeddings"].append(embedding)
                self.face_database[best_match]["faces"].append(face_img)
                self.face_database[best_match]["image_paths"].append(img_path)
            else:
                new_person_tag = f"person_{next_person_id}"
                updated_tags[img_path] = new_person_tag
                self.face_database[new_person_tag] = {
                    "embeddings": [embedding],
                    "faces": [face_img],
                    "image_paths": [img_path],
                }
                next_person_id += 1

        return updated_tags

    def process_faces(self, image_urls: List[str]):
        """ 인물 태깅 실행 함수 """
        face_data = self.get_face_embeddings(image_urls)
        batch_tags = self.cluster_faces_hierarchical(face_data)
        final_tags = self.match_with_database(batch_tags, face_data)

        return final_tags