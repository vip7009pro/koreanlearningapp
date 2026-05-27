function extractSentenceFromHtml(html: string, orderIndex: number): string | null {
  if (!html) return null;
  const text = html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();

  const getMarkers = (idx: number) => {
    const circled1 = String.fromCharCode(9311 + idx); // ①, ②
    const circled2 = String.fromCharCode(10111 + idx); // ➀, ➁
    return [
      `(${idx})`,
      `[${idx}]`,
      `${idx}.`,
      circled1,
      circled2,
      `( ${circled1} )`,
      `( ${circled2} )`,
      `(${circled1})`,
      `(${circled2})`,
      idx === 1 ? '(ㄱ)' : idx === 2 ? '(ㄴ)' : idx === 3 ? '(ㄷ)' : idx === 4 ? '(ㄹ)' : '',
      idx === 1 ? 'ㄱ' : idx === 2 ? 'ㄴ' : idx === 3 ? 'ㄷ' : idx === 4 ? 'ㄹ' : '',
    ].filter(Boolean);
  };

  const markersCurrent = getMarkers(orderIndex);
  const markersNext = getMarkers(orderIndex + 1);

  let startIdx = -1;
  for (const marker of markersCurrent) {
    const pos = text.indexOf(marker);
    if (pos !== -1) {
      startIdx = pos + marker.length;
      break;
    }
  }

  if (startIdx === -1) return null;

  let endIdx = text.length;
  for (const marker of markersNext) {
    const pos = text.indexOf(marker, startIdx);
    if (pos !== -1) {
      endIdx = pos;
      break;
    }
  }

  let sentence = text.slice(startIdx, endIdx).trim();
  sentence = sentence.replace(/^\s*\)\s*/, '').replace(/\s*\(\s*$/, '');
  sentence = sentence.replace(/^\s*\]\s*/, '').replace(/\s*\[\s*$/, '');
  sentence = sentence.replace(/^[:.-\s]+/, '').replace(/[:.-\s]+$/, '').trim();

  return sentence || null;
}

const html = "최근 스마트폰 사용 시간이 늘어나면서 '디지털 디톡스'에 대한 관심이 높아지고 있다. (1) 디지털 디톡스는 일정 기간 전자기기 사용을 중단하는 것을 말한다. (2) 이를 통해 현대인들은 뇌에 휴식을 주고 스트레스를 줄일 수 있다. (3) 스마트폰은 전 세계 어디서나 빠르게 정보를 검색할 수 있게 해준다. (4) 따라서 의도적으로 디지털 기기와 거리를 두는 습관이 필요하다.";

console.log('Q46 Extracted:');
for (let i = 1; i <= 4; i++) {
  console.log(`Choice ${i}: "${extractSentenceFromHtml(html, i)}"`);
}
