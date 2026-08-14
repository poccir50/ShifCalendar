from pathlib import Path

p = Path('index.html')
s = p.read_text(encoding='utf-8')

if 'rel="manifest"' not in s:
    s = s.replace(
        '<title>ShiftMate · 교대근무 달력</title>',
        '<link rel="manifest" href="manifest.webmanifest">\n<link rel="icon" href="icon.svg" type="image/svg+xml">\n<title>ShiftMate · 교대근무 달력</title>'
    )

s = s.replace('onclick="askNotify()">🔔 알림 권한</button>', 'onclick="askNotify()">🔔 알림 테스트</button>')
s = s.replace(
    '웹앱의 04:50 알림은 iPhone에서 앱이 닫혀 있으면 정확한 시각에 울린다고 보장할 수 없습니다. 실제 기상용으로는 아이폰 시계 알람을 함께 유지하는 것을 권장합니다.',
    'iPhone에서는 Safari 탭이 아니라 홈 화면에 추가한 ShiftMate에서 알림을 허용해야 합니다. 앱을 켜둔 동안에는 기상·개인일정 알림을 보낼 수 있습니다. 앱이 완전히 닫힌 상태의 04:50 자동 알림은 별도 Push 서버 없이는 보장할 수 있으므로 실제 기상용으로는 아이폰 시계 알람도 유지하세요.'
)

start = s.find('async function askNotify(){')
end_marker = 'setInterval(checkNotify,30000);'
end = s.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit('notification block not found')
end += len(end_marker)

new_block = r'''async function getSW(){
  if(!('serviceWorker' in navigator))throw new Error('Service Worker 미지원');
  await navigator.serviceWorker.register('./sw.js');
  return await navigator.serviceWorker.ready;
}
function isIOS(){return /iPhone|iPad|iPod/i.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1)}
function standalone(){return (window.matchMedia&&window.matchMedia('(display-mode: standalone)').matches)||window.navigator.standalone===true}
async function askNotify(){
  if(isIOS()&&!standalone())return alert('iPhone에서는 Safari가 아니라 홈 화면에 추가한 ShiftMate 아이콘으로 실행한 뒤 이 버튼을 눌러주세요.');
  if(!('Notification' in window)||!('serviceWorker' in navigator))return alert('이 실행 환경에서는 웹 알림을 사용할 수 없습니다.');
  try{
    let permission=await Notification.requestPermission();
    if(permission!=='granted')return alert('알림 권한이 허용되지 않았습니다. iPhone 설정 → 알림 → ShiftMate도 확인해주세요.');
    let reg=await getSW();
    await reg.showNotification('ShiftMate 알림 테스트',{body:'이 알림이 보이면 실행 중 알림 기능은 정상입니다.',tag:'shiftmate-test-'+Date.now()});
  }catch(e){alert('알림 테스트 실패: '+(e&&e.message?e.message:e))}
}
async function showShiftNotification(title,body,tag){
  if(!('Notification' in window)||Notification.permission!=='granted')return;
  try{let reg=await getSW();await reg.showNotification(title,{body,tag})}catch(e){console.error(e)}
}
async function checkNotify(){
  let n=new Date(),hm=`${pad(n.getHours())}:${pad(n.getMinutes())}`;
  if(hm===S.wake&&shift(n)==='주간'){
    let k='sm.notify.'+key(n);
    if(!sessionStorage.getItem(k)){await showShiftNotification('기상 시간',`${S.team} 주간근무 · ${S.ds} 출근`,k);sessionStorage.setItem(k,'1')}
  }
  for(let [dateKey,arr] of Object.entries(E))for(let ev of arr){
    let reminder=ev.rem??ev.reminder??'none';
    if(!ev.time||reminder==='none')continue;
    let eventDate=new Date(`${dateKey}T${ev.time}:00`),trigger=new Date(eventDate.getTime()-Number(reminder)*60000);
    if(Math.abs(n-trigger)<45000){
      let k=`sm.event.${dateKey}.${ev.id}.${reminder}`;
      if(!sessionStorage.getItem(k)){await showShiftNotification(ev.title,`${dateKey} ${ev.time}${ev.memo?' · '+ev.memo:''}`,k);sessionStorage.setItem(k,'1')}
    }
  }
}
setInterval(checkNotify,30000);setTimeout(checkNotify,1500);'''

s = s[:start] + new_block + s[end:]

reg_code = "\nif('serviceWorker' in navigator){window.addEventListener('load',async()=>{try{let r=await navigator.serviceWorker.register('./sw.js');await r.update()}catch(e){console.error(e)}})}\n"
if "window.addEventListener('load',async()=>" not in s:
    s = s.replace('</script>\n</body>', reg_code + '</script>\n</body>')

p.write_text(s, encoding='utf-8')

Path('manifest.webmanifest').write_text('''{
  "name":"ShiftMate 교대근무 달력",
  "short_name":"ShiftMate",
  "start_url":"./",
  "display":"standalone",
  "background_color":"#f5f6f8",
  "theme_color":"#111827",
  "lang":"ko-KR",
  "icons":[{"src":"icon.svg","sizes":"any","type":"image/svg+xml","purpose":"any maskable"}]
}''', encoding='utf-8')

Path('icon.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" rx="112" fill="#111827"/><rect x="92" y="106" width="328" height="300" rx="48" fill="#fff"/><rect x="146" y="190" width="100" height="100" rx="18" fill="#fef3c7"/><rect x="266" y="190" width="100" height="100" rx="18" fill="#dbeafe"/><text x="256" y="365" text-anchor="middle" font-family="Arial" font-size="96" font-weight="700" fill="#111827">S</text></svg>''', encoding='utf-8')

Path('sw.js').write_text(r'''const CACHE='shiftmate-v5';
const ASSETS=['./','./index.html','./manifest.webmanifest','./icon.svg'];
self.addEventListener('install',e=>{self.skipWaiting();e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS)))});
self.addEventListener('activate',e=>e.waitUntil((async()=>{for(const k of await caches.keys())if(k!==CACHE)await caches.delete(k);await self.clients.claim()})()));
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;e.respondWith(fetch(e.request).then(r=>{let c=r.clone();caches.open(CACHE).then(x=>x.put(e.request,c));return r}).catch(()=>caches.match(e.request).then(r=>r||caches.match('./index.html'))))});
self.addEventListener('notificationclick',e=>{e.notification.close();e.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(list=>{for(const c of list)if('focus' in c)return c.focus();if(clients.openWindow)return clients.openWindow('./')}))});
''', encoding='utf-8')
