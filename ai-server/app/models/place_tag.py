import torch
import clip
import torch.nn.functional as F
from PIL import Image
import logging
import time
from app.utils.places import places

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class PlaceTagger:
    def __init__(self, model_name="ViT-L/14", threshold=0.4):
        try:
            logger.info(f"🔧 PlaceTagger 초기화 시작 (model: {model_name}, threshold: {threshold})")
            self.model_name = model_name
            self.threshold = threshold
            
            # GPU 설정 및 검증
            if torch.backends.mps.is_available():
                self.device = torch.device("mps")
                logger.info("✅ MPS 사용 가능: Apple Silicon GPU 사용")
            else:
                self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
                logger.info(f"⚠️ MPS 사용 불가: {self.device} 사용")
            
            # CLIP 모델 로드
            start_time = time.time()
            self.model, self.preprocess = clip.load(model_name, self.device)
            load_time = time.time() - start_time
            logger.info(f"✅ CLIP 모델 로드 완료 (소요시간: {load_time:.2f}초)")
            
            # 프롬프트 수정 - outdoor scene 제거
            self.prompt_template = "a photo of {}"  # 더 일반적인 프롬프트로 변경
            self.labels = [self.prompt_template.format(place) for place in places.keys()]
            logger.info(f"✅ 프롬프트 설정 완료 (레이블 수: {len(self.labels)}개)")
            
        except Exception as e:
            logger.error(f"❌ PlaceTagger 초기화 실패: {str(e)}", exc_info=True)
            raise

    def _validate_image(self, image):
        """이미지 유효성 검사 및 전처리"""
        if image is None:
            raise ValueError("이미지가 None입니다")
        
        # 이미지 모드 검사
        if image.mode != 'RGB':
            logger.info(f"⚠️ 이미지 모드 변환: {image.mode} → RGB")
            image = image.convert('RGB')
        
        # 이미지 크기 검사
        min_size = 224
        original_size = image.size
        if image.size[0] < min_size or image.size[1] < min_size:
            logger.warning(f"⚠️ 이미지 크기가 너무 작음: {original_size} → ({min_size}, {min_size})")
            image = image.resize((min_size, min_size), Image.LANCZOS)
        
        logger.debug(f"✅ 이미지 검증 완료: 크기={image.size}, 모드={image.mode}")
        return image

    def predict_places(self, image_data_dict: dict, top_k=3) -> dict:
        """장소 태깅 (배치 처리)"""
        results = {}
        total_images = len(image_data_dict)
        processed_count = 0
        error_count = 0
        
        logger.info(f"🚀 장소 태깅 시작: 총 {total_images}개 이미지")
        batch_start_time = time.time()

        for image_url, image in image_data_dict.items():
            try:
                processed_count += 1
                logger.info(f"🔍 [{processed_count}/{total_images}] 이미지 처리 중: {image_url}")
                image_start_time = time.time()

                # 이미지 검증 및 전처리
                image = self._validate_image(image)
                
                # CLIP 입력 준비 부분 수정
                try:
                    # 이미지 변환 수정
                    image_transforms = []
                    transforms = [
                        lambda x: x,  # 원본
                        lambda x: x.transpose(Image.FLIP_LEFT_RIGHT)  # 좌우 반전
                    ]
                    
                    for transform in transforms:
                        processed = self.preprocess(transform(image))
                        image_transforms.append(processed)
                    
                    # 텐서 스택 수정 (배치 차원 올바르게 처리)
                    image_tensors = torch.cat([t.unsqueeze(0) for t in image_transforms], dim=0).to(self.device)
                    
                    # 텐서 shape 로깅 추가
                    logger.debug(f"이미지 텐서 shape: {image_tensors.shape}")
                    
                    text_inputs = clip.tokenize(self.labels).to(self.device)

                    # 예측 수행
                    with torch.no_grad():
                        # 이미지 특징 추출
                        image_features = self.model.encode_image(image_tensors)
                        text_features = self.model.encode_text(text_inputs)
                        
                        # 유사도 계산
                        similarity = F.softmax(
                            (image_features @ text_features.T).mean(dim=0).unsqueeze(0), 
                            dim=-1
                        )

                        # 상위 결과 추출
                        best_match_indices = similarity.argsort(descending=True)[0][:top_k]
                        best_places = [
                            (self.labels[idx], float(similarity[0, idx].item()))
                            for idx in best_match_indices
                        ]
                        
                        # 임계값 기반 필터링
                        valid_places = [
                            place for place in best_places 
                            if place[1] >= self.threshold
                        ]

                        # 결과 저장
                        if valid_places:
                            place_name = valid_places[0][0].replace("a photo of ", "")
                            results[image_url] = {
                                "place": places.get(place_name, place_name),
                                "confidence": valid_places[0][1],
                                "all_predictions": [
                                    {"place": p[0], "confidence": p[1]} 
                                    for p in best_places[:3]
                                ]
                            }
                            
                            process_time = time.time() - image_start_time
                            # 상세 로깅 추가
                            logger.info(
                                f"✅ 태깅 완료: {image_url}\n"
                                f"   - 최종 선택 장소: {results[image_url]['place']} (신뢰도: {results[image_url]['confidence']:.4f})\n"
                                f"   - 상위 3개 후보:\n" + 
                                "\n".join([
                                    f"     {i+1}. {p[0].replace('a photo of ', '')} "  # outdoor scene 제거
                                    f"(신뢰도: {p[1]:.4f})"
                                    for i, p in enumerate(best_places[:3])
                                ]) + f"\n"
                                f"   - 처리시간: {process_time:.2f}초"
                            )
                        else:
                            error_count += 1
                            results[image_url] = {
                                "error": "임계값을 넘는 장소가 없음",
                                "best_guess": best_places[0] if best_places else None
                            }
                            # 임계값을 넘지 못한 경우에도 상위 후보 로깅
                            logger.warning(
                                f"⚠️ 유효한 장소 없음: {image_url}\n" +
                                "   - 상위 3개 후보 (임계값 {self.threshold} 미만):\n" +
                                "\n".join([
                                    f"     {i+1}. {p[0].replace('a photo of ', '')} "  # outdoor scene 제거
                                    f"(신뢰도: {p[1]:.4f})"
                                    for i, p in enumerate(best_places[:3])
                                ])
                            )

                except Exception as e:
                    error_count += 1
                    results[image_url] = {"error": str(e)}
                    logger.error(f"❌ 처리 실패: {image_url}", exc_info=True)

            except Exception as e:
                error_count += 1
                results[image_url] = {"error": str(e)}
                logger.error(f"❌ 처리 실패: {image_url}", exc_info=True)

        # 최종 통계
        total_time = time.time() - batch_start_time
        success_rate = ((total_images - error_count) / total_images) * 100
        
        logger.info(
            f"\n📊 처리 완료 통계:\n"
            f"   - 총 이미지: {total_images}개\n"
            f"   - 성공: {total_images - error_count}개\n"
            f"   - 실패: {error_count}개\n"
            f"   - 성공률: {success_rate:.1f}%\n"
            f"   - 총 소요시간: {total_time:.2f}초\n"
            f"   - 이미지당 평균 처리시간: {total_time/total_images:.2f}초"
        )

        return results