# 복원 파츠

- 아가미 6개, 꼬리 장식 3개, 장식 아래 꼬리 피부, 전경 몸체: 총 11개 그룹입니다.
- Restored hidden artwork / Restored seam finish는 가려졌던 형태와 접합부를 보완하는 레이어입니다. 보이지 않던 모양은 추정 복원입니다.
- 원본은 SOURCE_BACKUP_hidden 그룹에 보관했습니다. Dropbox 원본은 변경하지 않았습니다.
- PNG는 모두 1086×1448 전체 캔버스와 투명 알파를 사용합니다. manifest에 표시 순서와 임시 회전 중심을 기록했습니다.
- rotation_check.gif는 각 장식을 약 ±4도로 움직인 점검용이며, 완성된 idle 리깅은 아닙니다.
- 저장된 PSD를 다시 열어 PNG로 내보내고 개별 PNG 재합성과 비교했습니다. 결과는 export_validation.json에 있습니다. Procreate에서 직접 열어 본 검증은 아닙니다.
- 복원으로 가려진 형상과 일부 겹침 경계가 추가되어 원본과 픽셀 단위로 동일하지 않습니다.

## 이미지 편집 기록
내장 imagegen 사용. 편집 지시 요약: 원래 색상과 굵은 검은 외곽선을 참고하여 9개 분홍 장식의 가려진 뿌리를 완성하고 투명 배경으로 만들기. 꼬리에서는 장식 3개를 제거하고 아래의 연분홍 피부와 윤곽 복원하기. 생성 결과의 채색을 원본 PSD의 복원 영역에 맞추어 사용했습니다.
입력 참조: ../axolotl_parts/parts_overview.png, source_preview.png, tail_detail.png.
생성 원본: restored_atlas_source.png, restored_tail_source.png.
