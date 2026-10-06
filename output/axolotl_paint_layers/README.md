# 검증된 PSD

최종 파일: axolotl_verified_v3.psd
선화(Line Art) / 명암(Shading) / 밑색(Base Color), 일반 합성, 8비트 RGBA, sRGB.

PSD 저장을 표준 라이브러리 방식으로 교체했습니다. 각 레이어는 별도 마스크가 아닌 실제 투명도 채널(-1)을 사용합니다. 서로 다른 두 PSD 리더에서 모든 레이어의 RGBA 데이터가 저장 전과 정확히 일치함을 확인했습니다. 저장된 PSD에서 추출한 PNG들을 합성하여 원본 캐릭터와 비교한 결과, RGB 채널 차이는 최대 1/255였습니다. 종이 배경과 주변 낙서는 비교에서 제외했습니다.

verified_psd_export.png: PSD의 레이어 PNG를 다시 합친 결과.
verified_source_vs_export.png: 왼쪽 첨부 원본, 오른쪽 PSD 내보내기(흰 배경으로 비교).
verified_exports/3_Line_Art.png: PSD에서 추출한 투명 선화.

Procreate 앱에서 직접 열어 보는 검증은 이 환경에서 수행하지 못했습니다.
이전 psd_export.png는 잘못된 PNG 변환 코드로 생성된 결과이므로 사용하지 마세요.
