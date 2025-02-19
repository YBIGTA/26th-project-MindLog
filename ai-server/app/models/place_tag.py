import torch
import clip
import torch.nn.functional as F
from PIL import Image
from utils.places import places

# ✅ PlaceTagger 클래스 정의
class PlaceTagger:
    def __init__(self, model_name="ViT-B/32", threshold=0.3):
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.model, self.preprocess = clip.load(model_name, self.device)
        self.threshold = threshold
        self.labels = list(places.keys())

    def preprocess_image(self, image_path: str):
        """이미지 전처리 함수 (URL에서 이미지 불러오기)"""
        image = Image.open(image_path).convert("RGB")
        return self.preprocess(image).unsqueeze(0).to(self.device)

    def predict_places(self, image_urls: list[str], top_k=3) -> dict:
        """
        🔹 장소 태깅 (배치 처리)
        - 여러 이미지 URL을 입력받아 한 번에 태깅 수행
        - 장소 태깅 결과를 딕셔너리 형태로 반환
        """
        results = {}

        for image_url in image_urls:
            try:
                image = self.preprocess_image(image_url)
                text_inputs = clip.tokenize(self.labels).to(self.device)

                with torch.no_grad():
                    image_features = self.model.encode_image(image)
                    text_features = self.model.encode_text(text_inputs)
                    similarity = (image_features @ text_features.T)
                    similarity = F.softmax(similarity, dim=-1)

                    best_match_indices = similarity.argsort(descending=True)[0][:top_k]
                    best_places = [(self.labels[idx], float(similarity[0, idx].item())) for idx in best_match_indices]
                    valid_places = [place for place in best_places if place[1] >= self.threshold]

                    if valid_places:
                        results[image_url] = {
                            "place": places.get(valid_places[0][0], valid_places[0][0]),
                            "confidence": valid_places[0][1]
                        }
                    else:
                        results[image_url] = {"error": "No valid place detected"}

            except Exception as e:
                results[image_url] = {"error": str(e)}

        return results
