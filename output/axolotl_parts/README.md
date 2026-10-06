# 아홀로틀 파츠 분리본

원본: C:/Users/jaynap/Dropbox/axolotl_verified_v3.psd
결과: axolotl_gills_tail_parts.psd

- 머리 아가미 6개: Gill_L/R_Upper, Middle, Lower. L/R은 화면 기준입니다.
- 꼬리 장식 3개: Tail_Root(몸 쪽), Tail_Middle, Tail_Tip(꼬리 끝 쪽).
- 나머지 캐릭터는 Body 그룹입니다.
- 각 그룹 내부에 Base Color / Shading / Line Art를 유지했습니다. 수정 원본의 명암 클리핑도 보존했습니다.
- SOURCE_BACKUP_hidden에는 수정 원본의 다섯 레이어를 숨김 상태로 보관했습니다.
- parts_png의 PNG는 모두 원본과 같은 1086×1448 캔버스와 위치를 사용하며 배경은 투명합니다.
- parts_manifest.json의 회전 중심은 리깅 시작용 제안 좌표입니다. 리깅이나 애니메이션은 아직 추가하지 않았습니다.

저장된 PSD의 레이어 합성 및 개별 PNG 재합성은 수정 원본의 보이는 RGB와 알파에 대해 픽셀 차이 0을 확인했습니다.

이번 파일은 보이는 영역의 파츠 분리본입니다. 가려진 아가미 뿌리, 장식 아래 꼬리 피부 등은 새로 그리지 않았습니다. idle 리깅 전에 회전에 의해 드러나는 부분을 보완해야 합니다.
