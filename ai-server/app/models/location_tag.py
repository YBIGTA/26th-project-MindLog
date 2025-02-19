import requests
import exifread
import time
from typing import Dict
from PIL import Image
from io import BytesIO

class LocationTagger:
    def __init__(self, user_agent="Mozilla/5.0"):
        self.headers = {"User-Agent": user_agent}

    def convert_to_decimal(self, gps_value):
        """ GPS 분수 좌표를 소수점 좌표로 변환 """
        return float(gps_value[0]) + float(gps_value[1]) / 60 + float(gps_value[2].num) / float(gps_value[2].den) / 3600

    def get_gps_from_exif(self, image_url: str):
        """ 이미지의 EXIF 데이터에서 GPS 정보를 추출하는 함수 """
        try:
            response = requests.get(image_url)
            image = Image.open(BytesIO(response.content))
            tags = exifread.process_file(image.fp)

            if 'GPS GPSLatitude' in tags and 'GPS GPSLongitude' in tags:
                lat_values = tags['GPS GPSLatitude'].values
                lon_values = tags['GPS GPSLongitude'].values
                lat_ref = tags.get('GPS GPSLatitudeRef', 'N').values
                lon_ref = tags.get('GPS GPSLongitudeRef', 'E').values

                lat = self.convert_to_decimal(lat_values)
                lon = self.convert_to_decimal(lon_values)

                if lat_ref != 'N': lat = -lat
                if lon_ref != 'E': lon = -lon

                print(f"✅ {image_url} → GPS 좌표: ({lat}, {lon})")
                return lat, lon
        except Exception as e:
            print(f"⚠️ {image_url} → GPS 데이터 읽기 실패: {e}")

        return None, None  # GPS 정보가 없는 경우

    def get_full_address(self, lat, lon):
        """ OpenStreetMap API를 활용하여 GPS 좌표를 전체 주소로 변환 """
        if lat is None or lon is None:
            print("⚠️ GPS 정보 없음 → 주소 변환 불가")
            return None

        url = f"https://nominatim.openstreetmap.org/reverse?format=json&lat={lat}&lon={lon}&zoom=14&addressdetails=1"

        try:
            time.sleep(1)  # API 요청 제한 방지
            response = requests.get(url, headers=self.headers, timeout=5)
            if response.status_code == 200:
                address = response.json().get("address", {})
                print(f"📍 주소 변환 성공: {address}")
                return address
        except requests.exceptions.RequestException as e:
            print(f"⚠️ 주소 변환 실패: {e}")

        return None

    def extract_best_region_tag(self, address):
        """ OpenStreetMap에서 가져온 주소에서 최적의 지역 태그 추출 """
        if not address:
            print("🚨 주소 정보 없음 → 지역 태그 생성 불가")
            return None

        region_priority = ["quarter", "suburb", "town", "village", "borough", "county", "city_district"]
        for key in region_priority:
            if key in address:
                return address[key]

        return None

    def predict_locations(self, image_urls: list[str]) -> dict:
        """ 🔹 GPS 정보가 없더라도 '지역 태그 없음'을 반환하고 계속 진행 """
        results = {}
        for image_url in image_urls:
            try:
                lat, lon = self.get_gps_from_exif(image_url)
                if lat is None or lon is None:
                    print(f"⚠️ {image_url} → GPS 정보 없음 → 기본값 반환")
                    results[image_url] = {"error": "지역 태그 없음"}
                    continue

                full_address = self.get_full_address(lat, lon)
                best_tag = self.extract_best_region_tag(full_address)

                results[image_url] = {"region": best_tag} if best_tag else {"error": "지역 태그 없음"}
                print(f"📍 {image_url} → 지역 태그: {results[image_url]}")

            except Exception as e:
                print(f"⚠️ {image_url} → 지역 태그 생성 실패: {e}")
                results[image_url] = {"error": "지역 태그 생성 실패"}

        return results
