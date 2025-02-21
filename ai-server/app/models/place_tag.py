import torch
import clip
import torch.nn.functional as F
import requests
from io import BytesIO
from PIL import Image
from app.utils.places import places

class PlaceTagger:
    def __init__(self, model_name="ViT-B/32", threshold=0.3):
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.model, self.preprocess = clip.load(model_name, self.device)
        self.threshold = threshold
        self.labels = list(places.keys())

    def load_image(self, image_path: str):
        """🔹 로컬 파일 및 URL 지원 (이미지 로드)"""
        try:
            if image_path.startswith("http"):  # 🔹 URL에서 이미지 다운로드
                response = requests.get(image_path, timeout=5)
                response.raise_for_status()
                image = Image.open(BytesIO(response.content)).convert("RGB")
            else:
                image = Image.open(image_path).convert("RGB")  # 🔹 로컬 파일 로드
            return self.preprocess(image).unsqueeze(0).to(self.device)
        except Exception as e:
            print(f"⚠️ 이미지 로드 실패: {image_path}, 오류: {e}")
            return None

    def predict_places(self, image_urls: list[str], top_k=3) -> dict:
        """
        🔹 장소 태깅 (배치 처리)
        - 여러 이미지 URL을 입력받아 한 번에 태깅 수행
        - 장소 태깅 결과를 딕셔너리 형태로 반환
        """
        results = {}

        print(f"🚀 장소 태깅 시작: {len(image_urls)}개의 이미지 처리 중...")  # ✅ 전체 처리 시작 로그

        for image_url in image_urls:
            print(f"🔍 장소 태깅 진행 중: {image_url}")  # ✅ 개별 이미지 처리 로그
            image = self.load_image(image_url)
            if image is None:
                results[image_url] = {"error": "이미지 로드 실패"}
                print(f"⚠️ 장소 태깅 실패: {image_url} → 이미지 로드 실패")  # ✅ 실패 로그 추가
                continue

            try:
                text_inputs = clip.tokenize(self.labels).to(self.device)

                with torch.no_grad():
                    image_features = self.model.encode_image(image)
                    text_features = self.model.encode_text(text_inputs)
                    similarity = F.softmax(image_features @ text_features.T, dim=-1)

                    best_match_indices = similarity.argsort(descending=True)[0][:top_k]
                    best_places = [(self.labels[idx], float(similarity[0, idx].item())) for idx in best_match_indices]
                    valid_places = [place for place in best_places if place[1] >= self.threshold]

                    if valid_places:
                        results[image_url] = {
                            "place": places.get(valid_places[0][0], valid_places[0][0]),
                            "confidence": valid_places[0][1]
                        }
                        print(f"✅ 장소 태깅 완료: {image_url} → {results[image_url]}")  # ✅ 성공 로그 추가
                    else:
                        results[image_url] = {"error": "No valid place detected"}
                        print(f"⚠️ 장소 태깅 실패: {image_url} → No valid place detected")  # ✅ 실패 로그 추가

            except Exception as e:
                results[image_url] = {"error": str(e)}
                print(f"❌ 장소 태깅 오류: {image_url}, 오류: {e}")  # ✅ 예외 발생 시 로그

        print("✅ 장소 태깅 프로세스 완료")  # ✅ 전체 프로세스 완료 로그
        return results
