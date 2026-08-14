from pathlib import Path

p = Path('index.html')
s = p.read_text(encoding='utf-8')

if 'subscribeCalendar()' not in s:
    old = 'onclick="exportBackup()">💾 백업</button></div>'
    new = 'onclick="exportBackup()">💾 백업</button><button class="btn" onclick="subscribeCalendar()">📅 아이폰 캘린더 연결</button></div>'
    if old not in s:
        raise SystemExit('actions block not found')
    s = s.replace(old, new, 1)

if 'function subscribeCalendar()' not in s:
    marker = 'function download(n,t)'
    fn = """function subscribeCalendar(){
  const webcal='webcal://poccir50.github.io/ShifCalendar/shiftmate.ics';
  const https='https://poccir50.github.io/ShifCalendar/shiftmate.ics';
  if(/iPhone|iPad|iPod/i.test(navigator.userAgent)){
    if(confirm('아이폰 캘린더에 ShiftMate A조 근무표를 구독할까요?\\n\\n2026년 회사 휴무와 주·야간 근무, 주간근무일 04:50 기상 일정이 포함됩니다.')) location.href=webcal;
  }else{
    window.open(https,'_blank');
  }
}
"""
    if marker not in s:
        raise SystemExit('download marker not found')
    s = s.replace(marker, fn + marker, 1)

old_warn = 'iPhone에서는 Safari 탭이 아니라 홈 화면의 ShiftMate에서 알림을 허용해야 합니다. 앱을 켜둔 동안에는 알림을 보낼 수 있지만, 앱이 완전히 닫힌 상태의 04:50 자동 알림은 별도 Push 서버 없이는 보장할 수 없습니다. 실제 기상용으로는 아이폰 시계 알람을 함께 유지하세요.'
new_warn = '가장 안정적인 방식은 📅 아이폰 캘린더 연결입니다. 2026년 A조 주·야간 근무와 회사휴무, 주간근무일 04:50 기상 일정이 iPhone 캘린더에 구독됩니다. 캘린더 알림은 iPhone 설정의 알림·집중모드 영향을 받으며 시계 앱의 알람과는 다릅니다.'
s = s.replace(old_warn, new_warn)

p.write_text(s, encoding='utf-8')
