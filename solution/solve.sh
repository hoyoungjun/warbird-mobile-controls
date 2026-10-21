#!/bin/bash
set -euo pipefail

cd /app 2>/dev/null || cd /testbed 2>/dev/null

git apply --verbose <<'__SOLUTION__'
diff --git a/dist/index.html b/dist/index.html
index f8c587b..482cd33 100644
--- a/dist/index.html
+++ b/dist/index.html
@@ -22,6 +22,21 @@
     </div></footer>
     <button id="menu-toggle" class="menu-toggle" aria-label="Open flight menu">Esc</button>
   </main>
+  <section id="mobile-controls" class="mobile-controls" aria-label="Touch flight controls" hidden>
+    <div id="joystick" class="touch-joystick" data-mobile-control data-touch-joystick data-game-action="Pitch and roll: Space, ControlLeft, KeyQ, KeyE" role="slider" aria-label="Pitch and roll joystick" aria-valuetext="Neutral" tabindex="0">
+      <span class="touch-stick-axis" aria-hidden="true">Pitch</span>
+      <span class="touch-stick-knob" aria-hidden="true"></span>
+      <span class="touch-stick-axis touch-stick-axis-horizontal" aria-hidden="true">Roll</span>
+    </div>
+    <button id="btn-fire" class="touch-button touch-fire" type="button" data-mobile-control data-hold-action="fire" data-game-action="Fire: KeyF" aria-label="Fire" aria-pressed="false">Fire</button>
+    <button id="btn-yaw-right" class="touch-button" type="button" data-mobile-control data-hold-action="yawRight" data-game-action="Yaw right: KeyD" aria-label="Yaw right" aria-pressed="false">Yaw<br>R</button>
+    <button id="btn-collective-down" class="touch-button" type="button" data-mobile-control data-hold-action="collectiveDown" data-game-action="Lower collective: KeyS" aria-label="Lower collective" aria-pressed="false">Col<br>−</button>
+    <button id="btn-collective-up" class="touch-button" type="button" data-mobile-control data-hold-action="collectiveUp" data-game-action="Raise collective: KeyW" aria-label="Raise collective" aria-pressed="false">Col<br>+</button>
+    <button id="btn-yaw-left" class="touch-button" type="button" data-mobile-control data-hold-action="yawLeft" data-game-action="Yaw left: KeyA" aria-label="Yaw left" aria-pressed="false">Yaw<br>L</button>
+    <button id="btn-pause" class="touch-button" type="button" data-mobile-control data-tap-code="Escape" data-game-action="Pause: Escape" aria-label="Pause" aria-pressed="false">Pause</button>
+    <button id="btn-reset" class="touch-button" type="button" data-mobile-control data-tap-code="KeyR" data-game-action="Reset: KeyR" aria-label="Reset flight" aria-pressed="false">Reset</button>
+    <button id="btn-view" class="touch-button" type="button" data-mobile-control data-tap-code="KeyC" data-game-action="Change view: KeyC" aria-label="Change camera view" aria-pressed="false">Cam</button>
+  </section>
   <dialog id="setup-dialog" aria-label="Flight menu">
     <div class="dialog-head"><h2>Paused</h2><button class="close" aria-label="Close menu">×</button></div>
     <div class="setup-scroll">
diff --git a/dist/main.js b/dist/main.js
index cd6f69b..0fc3681 100644
--- a/dist/main.js
+++ b/dist/main.js
@@ -3,6 +3,7 @@ import {PALETTE,MONO_FONT} from './palette.js';
 import {Helicopter,DEFAULTS,V05_DEFAULTS,V04_DEFAULTS,PREVIOUS_DEFAULTS,ORIGINAL_DEFAULTS,migrateHandling,STEP,clamp} from './physics.js';
 import {GamepadInput,inputSettings} from './gamepad.js';
 import {Controls,BINDINGS,keyLabel,rebind} from './controls.js';
+import {MobileControls} from './mobile-controls.js';
 import {makeWorld,makeHelicopter,makeCockpit,groundHeight,pads,gates} from './world.js';
 import {DoodleRenderer,setAccent} from './rendering.js';
 import {FlightCamera,FlightPose,verticalFov} from './camera.js';
@@ -38,7 +39,7 @@ const targets=new Targets(world.targetPlacements);
 const weapons=new Miniguns(world.root,{zero:gunZero,targets});scene.add(weapons.effects);aircraft.setGunZero(gunZero);
 const hud=$('hud').getContext('2d'),map=$('map').getContext('2d');
 let mode='free',active=false,hasFlown=false,cockpit=false,missionDone=false,hoverTime=0,landingTime=0,gateIndex=0;
-let accumulator=0,previous=performance.now(),lastHUD=0,logClock=0,notificationTimer,dragChosen=false;
+let accumulator=0,previous=performance.now(),lastHUD=0,logClock=0,notificationTimer,dragChosen=false,mobileControls;
 let needsRender=true;
 let input={pitch:0,roll:0,yaw:0,collective:0},pulse=null,recording=[],recordDropped=false,sessionId=0;
 const MAX_RECORDS=24000; // Twenty minutes at 20 Hz, bounded in memory.
@@ -49,7 +50,7 @@ function dismissNotification(){clearTimeout(notificationTimer);$('notification')
 function toast(text,duration=4500){$('notification').textContent=text;$('notification').classList.add('show');clearTimeout(notificationTimer);if(duration>0)notificationTimer=setTimeout(dismissNotification,duration);}
 function save(){heli.config={...config};try{localStorage.setItem('rotor-lab-v1',JSON.stringify({version:'0.10.0',config,bindings,map:mapId,look,gunZero,inputs}));$('save-status').textContent='';}catch{$('save-status').textContent='Save unavailable';}}
 function stopFlight(){
-  active=false;accumulator=0;renderPose.reset(heli);controls.enabled=false;controls.clear();gamepad.clear();controllerUsed=false;audio.volume(0);
+  active=false;accumulator=0;renderPose.reset(heli);controls.enabled=false;controls.clear();mobileControls?.clear();gamepad.clear();controllerUsed=false;audio.volume(0);
   document.body.classList.remove('flying');
   if(document.pointerLockElement)document.exitPointerLock();
 }
@@ -57,9 +58,10 @@ const controls=new Controls($('scene'),config,bindings,{reset:()=>resetFlight(),
   if(locked){active=true;hasFlown=true;accumulator=0;renderPose.reset(heli);previous=performance.now();document.body.classList.add('flying');updateObjective();}
   else if(active)setup();
 },error:msg=>{setup();toast(msg,8000);}},inputs);
+mobileControls=new MobileControls($('mobile-controls'),$('scene'),{bindings});
 
 function resetFlight(){
-  dismissNotification();weapons.reset();gamepad.clear();
+  dismissNotification();weapons.reset();gamepad.clear();mobileControls?.clear();
   needsRender=true;
   flightCamera.reset();
   sessionId++;hoverTime=landingTime=gateIndex=0;missionDone=false;logClock=0;pulse=null;controls.clear();
@@ -78,6 +80,7 @@ $('challenge').addEventListener('change',e=>chooseMode(e.target.value));
 $('look-select').value=look;
 $('look-select').addEventListener('change',e=>{look=e.target.value==='natural'?'natural':'doodle';visual.setStyle(look);cockpitModel.setStyle(look);save();needsRender=true;});
 function startFlight(drag=false){
+  if(mobileControls?.enabled)drag=true;
   if(heli.crashed)resetFlight();dragChosen=drag;
   if($('setup-dialog').open)$('setup-dialog').close();
   audio.start();if(drag)controls.startDrag();else controls.lock();
@@ -220,7 +223,7 @@ function drawMap(t){
 }
 function drawHUD(t){
   const w=innerWidth,h=innerHeight;hud.clearRect(0,0,w,h);
-  const cx=w/2,instrumentY=h-120;hud.strokeStyle=PALETTE.ink+'99';hud.fillStyle=PALETTE.ink;hud.lineWidth=1;hud.font=`13px ${MONO_FONT}`;hud.textAlign='center';
+  const cx=w/2,instrumentY=mobileControls?.enabled&&h>w?h-240:h-120;hud.strokeStyle=PALETTE.ink+'99';hud.fillStyle=PALETTE.ink;hud.lineWidth=1;hud.font=`13px ${MONO_FONT}`;hud.textAlign='center';
   // Body pitch and bank are shown separately from flight-path direction.
   // No rectangular clip: banked ladder marks and labels keep their full extent.
   if(!cockpit){
diff --git a/dist/mobile-controls.js b/dist/mobile-controls.js
new file mode 100644
index 0000000..328bf8d
--- /dev/null
+++ b/dist/mobile-controls.js
@@ -0,0 +1,152 @@
+const clamp=(value,min=-1,max=1)=>Math.max(min,Math.min(max,value));
+
+const DEFAULT_BINDINGS=Object.freeze({
+  pitchUp:'Space',pitchDown:'ControlLeft',rollLeft:'KeyQ',rollRight:'KeyE',
+  yawLeft:'KeyA',yawRight:'KeyD',collectiveUp:'KeyW',collectiveDown:'KeyS'
+});
+
+export class MobileControls {
+  constructor(root,canvas,{bindings=DEFAULT_BINDINGS,media=globalThis.matchMedia?.('(pointer: coarse)')}={}){
+    this.root=root;this.canvas=canvas;this.bindings=bindings;this.media=media;
+    this.enabled=false;this.keyCounts=new Map();this.buttonPointers=new Map();
+    this.actionPointers=new Map();this.joystickPointer=null;this.joystickCodes=new Set();
+    this.joystick=root?.querySelector('[data-touch-joystick]')??null;
+    this.knob=this.joystick?.querySelector('.touch-stick-knob')??null;
+    if(!root)return;
+
+    this.bindJoystick();
+    for(const button of root.querySelectorAll('[data-hold-action]'))this.bindHoldButton(button);
+    for(const button of root.querySelectorAll('[data-tap-code]'))this.bindTapButton(button);
+    root.addEventListener('contextmenu',event=>event.preventDefault());
+    root.addEventListener('click',event=>event.preventDefault());
+
+    const clear=()=>this.clear();
+    globalThis.addEventListener?.('blur',clear);
+    globalThis.addEventListener?.('resize',clear);
+    globalThis.addEventListener?.('orientationchange',clear);
+    globalThis.document?.addEventListener('visibilitychange',()=>{if(document.hidden)clear();});
+    const update=()=>this.updateEnabled();
+    if(media?.addEventListener)media.addEventListener('change',update);
+    else media?.addListener?.(update);
+    this.updateEnabled();
+  }
+
+  updateEnabled(){
+    const touchPoints=Number(globalThis.navigator?.maxTouchPoints)||0;
+    const enabled=Boolean(this.media?.matches||touchPoints>0);
+    if(this.enabled&&!enabled)this.clear();
+    this.enabled=enabled;this.root.hidden=!enabled;
+    globalThis.document?.body?.classList.toggle('touch-controls-enabled',enabled);
+  }
+
+  codeFor(action){return this.bindings?.[action]||DEFAULT_BINDINGS[action];}
+
+  dispatchKey(type,code){
+    if(!code)return;
+    const target=this.canvas||globalThis.document?.body||globalThis;
+    target.dispatchEvent?.(new KeyboardEvent(type,{code,key:code,bubbles:true,cancelable:true}));
+  }
+
+  pressKey(code){
+    const count=this.keyCounts.get(code)||0;this.keyCounts.set(code,count+1);
+    if(count===0)this.dispatchKey('keydown',code);
+  }
+
+  releaseKey(code){
+    const count=this.keyCounts.get(code)||0;
+    if(count<=1){this.keyCounts.delete(code);if(count)this.dispatchKey('keyup',code);}
+    else this.keyCounts.set(code,count-1);
+  }
+
+  setJoystickCodes(next){
+    for(const code of this.joystickCodes)if(!next.has(code))this.releaseKey(code);
+    for(const code of next)if(!this.joystickCodes.has(code))this.pressKey(code);
+    this.joystickCodes=next;
+  }
+
+  bindJoystick(){
+    if(!this.joystick)return;
+    const move=event=>{
+      if(event.pointerId!==this.joystickPointer)return;
+      event.preventDefault();
+      const rect=this.joystick.getBoundingClientRect();
+      const cx=rect.left+rect.width/2,cy=rect.top+rect.height/2;
+      const limit=Math.min(rect.width,rect.height)*.31;
+      let dx=event.clientX-cx,dy=event.clientY-cy;
+      const distance=Math.hypot(dx,dy);
+      if(distance>limit){dx*=limit/distance;dy*=limit/distance;}
+      const x=clamp(dx/limit),y=clamp(dy/limit),deadzone=.18;
+      const next=new Set();
+      if(x < -deadzone)next.add(this.codeFor('rollLeft'));
+      if(x > deadzone)next.add(this.codeFor('rollRight'));
+      if(y < -deadzone)next.add(this.codeFor('pitchUp'));
+      if(y > deadzone)next.add(this.codeFor('pitchDown'));
+      this.setJoystickCodes(next);
+      this.knob?.style?.setProperty?.('--stick-x',`${dx.toFixed(1)}px`);
+      this.knob?.style?.setProperty?.('--stick-y',`${dy.toFixed(1)}px`);
+      this.joystick.setAttribute('aria-valuetext',next.size?'Engaged':'Neutral');
+    };
+    const release=event=>{
+      if(event.pointerId!==this.joystickPointer)return;
+      event.preventDefault();this.joystickPointer=null;this.setJoystickCodes(new Set());
+      this.knob?.style?.setProperty?.('--stick-x','0px');this.knob?.style?.setProperty?.('--stick-y','0px');
+      this.joystick.classList.remove('pressed');this.joystick.setAttribute('aria-valuetext','Neutral');
+    };
+    this.joystick.addEventListener('pointerdown',event=>{
+      if(!this.enabled||this.joystickPointer!==null)return;
+      event.preventDefault();this.joystickPointer=event.pointerId;
+      this.joystick.setPointerCapture?.(event.pointerId);this.joystick.classList.add('pressed');move(event);
+    });
+    this.joystick.addEventListener('pointermove',move);
+    this.joystick.addEventListener('pointerup',release);
+    this.joystick.addEventListener('pointercancel',release);
+    this.joystick.addEventListener('lostpointercapture',release);
+  }
+
+  bindHoldButton(button){
+    const release=event=>{
+      const held=this.buttonPointers.get(event.pointerId);if(!held||held.button!==button)return;
+      event.preventDefault();this.buttonPointers.delete(event.pointerId);this.releaseKey(held.code);
+      if(!Array.from(this.buttonPointers.values()).some(value=>value.button===button)){
+        button.classList.remove('pressed');button.setAttribute('aria-pressed','false');
+      }
+    };
+    button.addEventListener('pointerdown',event=>{
+      if(!this.enabled||this.buttonPointers.has(event.pointerId))return;
+      event.preventDefault();const action=button.dataset.holdAction;
+      const code=action==='fire'?'KeyF':this.codeFor(action);
+      this.buttonPointers.set(event.pointerId,{button,code});this.pressKey(code);
+      button.setPointerCapture?.(event.pointerId);button.classList.add('pressed');button.setAttribute('aria-pressed','true');
+    });
+    button.addEventListener('pointerup',release);
+    button.addEventListener('pointercancel',release);
+    button.addEventListener('lostpointercapture',release);
+  }
+
+  bindTapButton(button){
+    const cancel=event=>{
+      if(this.actionPointers.get(event.pointerId)!==button)return false;
+      this.actionPointers.delete(event.pointerId);button.classList.remove('pressed');button.setAttribute('aria-pressed','false');return true;
+    };
+    button.addEventListener('pointerdown',event=>{
+      if(!this.enabled)return;
+      event.preventDefault();this.actionPointers.set(event.pointerId,button);
+      button.setPointerCapture?.(event.pointerId);button.classList.add('pressed');button.setAttribute('aria-pressed','true');
+    });
+    button.addEventListener('pointerup',event=>{
+      if(!cancel(event))return;event.preventDefault();const code=button.dataset.tapCode;
+      this.dispatchKey('keydown',code);this.dispatchKey('keyup',code);
+    });
+    button.addEventListener('pointercancel',cancel);
+    button.addEventListener('lostpointercapture',cancel);
+  }
+
+  clear(){
+    this.joystickPointer=null;this.joystickCodes.clear();
+    for(const code of this.keyCounts.keys())this.dispatchKey('keyup',code);
+    this.keyCounts.clear();this.buttonPointers.clear();this.actionPointers.clear();
+    this.root?.querySelectorAll('.pressed').forEach(element=>{element.classList.remove('pressed');element.setAttribute('aria-pressed','false');});
+    this.knob?.style?.setProperty?.('--stick-x','0px');this.knob?.style?.setProperty?.('--stick-y','0px');
+    this.joystick?.setAttribute('aria-valuetext','Neutral');
+  }
+}
diff --git a/dist/style.css b/dist/style.css
index eaead50..690d117 100644
--- a/dist/style.css
+++ b/dist/style.css
@@ -12,3 +12,27 @@ p{font-size:13px;line-height:1.55;margin:15px 0}.muted,.preset-note{font-size:12
 @media(prefers-reduced-motion:reduce){*{transition:none!important}}
 
 .binding-row>span{flex:1}.binding-row button{font-family:inherit;font-size:12px}details{margin-top:14px}summary{cursor:pointer;color:var(--muted);font-size:12px;padding:6px 0}#calibration>a{display:inline-block;margin:12px 0 0 12px}.instruments,.mission-live,#notification,.menu-toggle{font-family:inherit}.mission-live strong{font-size:11px}#notification{font-size:12px}.menu-toggle{font-size:10px}
+
+.touch-controls-enabled,.touch-controls-enabled #scene{touch-action:none;overscroll-behavior:none}
+.mobile-controls{position:fixed;inset:0;z-index:30;pointer-events:none;touch-action:none;user-select:none;-webkit-user-select:none;-webkit-touch-callout:none}
+.mobile-controls [data-mobile-control]{position:absolute;pointer-events:auto;touch-action:none;margin:0;color:var(--ink);background:#eef2f4d9;border:1px solid #33414b80;box-shadow:0 2px 12px #33414b24}
+.touch-button{display:grid;place-items:center;width:44px;height:44px;padding:0;border-radius:50%;font-size:9px;line-height:1.05;text-transform:uppercase;letter-spacing:-.2px}
+.touch-button:hover{background:#eef2f4d9}.touch-button.pressed,.touch-button:active{background:var(--red);border-color:var(--red);color:#fff;transform:scale(.94)}
+.touch-fire{right:16px;bottom:16px;width:72px;height:72px;border:2px solid var(--red);font-size:12px;font-weight:700;letter-spacing:.6px}
+.touch-joystick{left:16px;bottom:16px;width:128px;height:128px;border-radius:50%;display:grid;place-items:center;overflow:hidden}
+.touch-joystick:before,.touch-joystick:after{content:'';position:absolute;background:#33414b28;pointer-events:none}.touch-joystick:before{left:18px;right:18px;height:1px}.touch-joystick:after{top:18px;bottom:18px;width:1px}
+.touch-stick-knob{position:absolute;width:48px;height:48px;border-radius:50%;background:#33414bb8;border:2px solid #eef2f4;transform:translate(var(--stick-x,0),var(--stick-y,0));transition:transform 80ms ease-out;z-index:2}
+.touch-joystick.pressed .touch-stick-knob{background:var(--red);transition:none}.touch-stick-axis{position:absolute;top:7px;font-size:7px;text-transform:uppercase;letter-spacing:.6px;color:var(--muted)}.touch-stick-axis-horizontal{top:auto;right:7px;writing-mode:vertical-rl}
+#btn-yaw-right{right:92px;bottom:16px}
+#btn-collective-down{right:116px;bottom:92px}#btn-collective-up{right:68px;bottom:92px}#btn-yaw-left{right:20px;bottom:92px}
+#btn-pause{right:116px;bottom:140px}#btn-reset{right:68px;bottom:140px}#btn-view{right:20px;bottom:140px}
+.touch-controls-enabled .nav{left:12px;top:12px;bottom:auto;padding:3px}.touch-controls-enabled #map{width:72px;height:72px}
+.touch-controls-enabled footer{top:12px;right:12px;bottom:auto;left:auto}.touch-controls-enabled .instruments{gap:8px;padding:6px 8px}.touch-controls-enabled .instruments>div{min-width:42px}.touch-controls-enabled .instruments strong{font-size:18px}.touch-controls-enabled .mission-live{top:96px;left:12px}.touch-controls-enabled .menu-toggle{display:none}
+@media(orientation:portrait){
+  .touch-joystick{left:12px;bottom:12px}
+  .touch-fire{right:12px;bottom:12px}
+  #btn-yaw-right{right:88px;bottom:12px}
+  #btn-collective-down{right:108px;bottom:88px}#btn-collective-up{right:60px;bottom:88px}#btn-yaw-left{right:12px;bottom:88px}
+  #btn-pause{right:108px;bottom:136px}#btn-reset{right:60px;bottom:136px}#btn-view{right:12px;bottom:136px}
+  .touch-controls-enabled footer{top:64px}.touch-controls-enabled .mission-live{top:124px}
+}
diff --git a/mobile-controls.json b/mobile-controls.json
new file mode 100644
index 0000000..d67b672
--- /dev/null
+++ b/mobile-controls.json
@@ -0,0 +1,107 @@
+{
+  "version": 1,
+  "viewports": [
+    {
+      "name": "compact-portrait",
+      "width": 390,
+      "height": 844,
+      "orientation": "portrait",
+      "controls": [
+        {"id": "joystick", "label": "Pitch and roll", "gameAction": "Space / ControlLeft / KeyQ / KeyE", "rect": {"x": 12, "y": 704, "width": 128, "height": 128}},
+        {"id": "btn-fire", "label": "Fire", "gameAction": "KeyF", "rect": {"x": 306, "y": 760, "width": 72, "height": 72}},
+        {"id": "btn-yaw-right", "label": "Yaw right", "gameAction": "KeyD", "rect": {"x": 258, "y": 788, "width": 44, "height": 44}},
+        {"id": "btn-collective-down", "label": "Lower collective", "gameAction": "KeyS", "rect": {"x": 238, "y": 712, "width": 44, "height": 44}},
+        {"id": "btn-collective-up", "label": "Raise collective", "gameAction": "KeyW", "rect": {"x": 286, "y": 712, "width": 44, "height": 44}},
+        {"id": "btn-yaw-left", "label": "Yaw left", "gameAction": "KeyA", "rect": {"x": 334, "y": 712, "width": 44, "height": 44}},
+        {"id": "btn-pause", "label": "Pause", "gameAction": "Escape", "rect": {"x": 238, "y": 664, "width": 44, "height": 44}},
+        {"id": "btn-reset", "label": "Reset", "gameAction": "KeyR", "rect": {"x": 286, "y": 664, "width": 44, "height": 44}},
+        {"id": "btn-view", "label": "Change view", "gameAction": "KeyC", "rect": {"x": 334, "y": 664, "width": 44, "height": 44}}
+      ]
+    },
+    {
+      "name": "compact-landscape",
+      "width": 844,
+      "height": 390,
+      "orientation": "landscape",
+      "controls": [
+        {"id": "joystick", "label": "Pitch and roll", "gameAction": "Space / ControlLeft / KeyQ / KeyE", "rect": {"x": 16, "y": 246, "width": 128, "height": 128}},
+        {"id": "btn-fire", "label": "Fire", "gameAction": "KeyF", "rect": {"x": 756, "y": 302, "width": 72, "height": 72}},
+        {"id": "btn-yaw-right", "label": "Yaw right", "gameAction": "KeyD", "rect": {"x": 708, "y": 330, "width": 44, "height": 44}},
+        {"id": "btn-collective-down", "label": "Lower collective", "gameAction": "KeyS", "rect": {"x": 684, "y": 254, "width": 44, "height": 44}},
+        {"id": "btn-collective-up", "label": "Raise collective", "gameAction": "KeyW", "rect": {"x": 732, "y": 254, "width": 44, "height": 44}},
+        {"id": "btn-yaw-left", "label": "Yaw left", "gameAction": "KeyA", "rect": {"x": 780, "y": 254, "width": 44, "height": 44}},
+        {"id": "btn-pause", "label": "Pause", "gameAction": "Escape", "rect": {"x": 684, "y": 206, "width": 44, "height": 44}},
+        {"id": "btn-reset", "label": "Reset", "gameAction": "KeyR", "rect": {"x": 732, "y": 206, "width": 44, "height": 44}},
+        {"id": "btn-view", "label": "Change view", "gameAction": "KeyC", "rect": {"x": 780, "y": 206, "width": 44, "height": 44}}
+      ]
+    },
+    {
+      "name": "large-portrait",
+      "width": 430,
+      "height": 932,
+      "orientation": "portrait",
+      "controls": [
+        {"id": "joystick", "label": "Pitch and roll", "gameAction": "Space / ControlLeft / KeyQ / KeyE", "rect": {"x": 12, "y": 792, "width": 128, "height": 128}},
+        {"id": "btn-fire", "label": "Fire", "gameAction": "KeyF", "rect": {"x": 346, "y": 848, "width": 72, "height": 72}},
+        {"id": "btn-yaw-right", "label": "Yaw right", "gameAction": "KeyD", "rect": {"x": 298, "y": 876, "width": 44, "height": 44}},
+        {"id": "btn-collective-down", "label": "Lower collective", "gameAction": "KeyS", "rect": {"x": 278, "y": 800, "width": 44, "height": 44}},
+        {"id": "btn-collective-up", "label": "Raise collective", "gameAction": "KeyW", "rect": {"x": 326, "y": 800, "width": 44, "height": 44}},
+        {"id": "btn-yaw-left", "label": "Yaw left", "gameAction": "KeyA", "rect": {"x": 374, "y": 800, "width": 44, "height": 44}},
+        {"id": "btn-pause", "label": "Pause", "gameAction": "Escape", "rect": {"x": 278, "y": 752, "width": 44, "height": 44}},
+        {"id": "btn-reset", "label": "Reset", "gameAction": "KeyR", "rect": {"x": 326, "y": 752, "width": 44, "height": 44}},
+        {"id": "btn-view", "label": "Change view", "gameAction": "KeyC", "rect": {"x": 374, "y": 752, "width": 44, "height": 44}}
+      ]
+    },
+    {
+      "name": "large-landscape",
+      "width": 932,
+      "height": 430,
+      "orientation": "landscape",
+      "controls": [
+        {"id": "joystick", "label": "Pitch and roll", "gameAction": "Space / ControlLeft / KeyQ / KeyE", "rect": {"x": 16, "y": 286, "width": 128, "height": 128}},
+        {"id": "btn-fire", "label": "Fire", "gameAction": "KeyF", "rect": {"x": 844, "y": 342, "width": 72, "height": 72}},
+        {"id": "btn-yaw-right", "label": "Yaw right", "gameAction": "KeyD", "rect": {"x": 796, "y": 370, "width": 44, "height": 44}},
+        {"id": "btn-collective-down", "label": "Lower collective", "gameAction": "KeyS", "rect": {"x": 772, "y": 294, "width": 44, "height": 44}},
+        {"id": "btn-collective-up", "label": "Raise collective", "gameAction": "KeyW", "rect": {"x": 820, "y": 294, "width": 44, "height": 44}},
+        {"id": "btn-yaw-left", "label": "Yaw left", "gameAction": "KeyA", "rect": {"x": 868, "y": 294, "width": 44, "height": 44}},
+        {"id": "btn-pause", "label": "Pause", "gameAction": "Escape", "rect": {"x": 772, "y": 246, "width": 44, "height": 44}},
+        {"id": "btn-reset", "label": "Reset", "gameAction": "KeyR", "rect": {"x": 820, "y": 246, "width": 44, "height": 44}},
+        {"id": "btn-view", "label": "Change view", "gameAction": "KeyC", "rect": {"x": 868, "y": 246, "width": 44, "height": 44}}
+      ]
+    },
+    {
+      "name": "android-portrait",
+      "width": 412,
+      "height": 915,
+      "orientation": "portrait",
+      "controls": [
+        {"id": "joystick", "label": "Pitch and roll", "gameAction": "Space / ControlLeft / KeyQ / KeyE", "rect": {"x": 12, "y": 775, "width": 128, "height": 128}},
+        {"id": "btn-fire", "label": "Fire", "gameAction": "KeyF", "rect": {"x": 328, "y": 831, "width": 72, "height": 72}},
+        {"id": "btn-yaw-right", "label": "Yaw right", "gameAction": "KeyD", "rect": {"x": 280, "y": 859, "width": 44, "height": 44}},
+        {"id": "btn-collective-down", "label": "Lower collective", "gameAction": "KeyS", "rect": {"x": 260, "y": 783, "width": 44, "height": 44}},
+        {"id": "btn-collective-up", "label": "Raise collective", "gameAction": "KeyW", "rect": {"x": 308, "y": 783, "width": 44, "height": 44}},
+        {"id": "btn-yaw-left", "label": "Yaw left", "gameAction": "KeyA", "rect": {"x": 356, "y": 783, "width": 44, "height": 44}},
+        {"id": "btn-pause", "label": "Pause", "gameAction": "Escape", "rect": {"x": 260, "y": 735, "width": 44, "height": 44}},
+        {"id": "btn-reset", "label": "Reset", "gameAction": "KeyR", "rect": {"x": 308, "y": 735, "width": 44, "height": 44}},
+        {"id": "btn-view", "label": "Change view", "gameAction": "KeyC", "rect": {"x": 356, "y": 735, "width": 44, "height": 44}}
+      ]
+    },
+    {
+      "name": "android-landscape",
+      "width": 915,
+      "height": 412,
+      "orientation": "landscape",
+      "controls": [
+        {"id": "joystick", "label": "Pitch and roll", "gameAction": "Space / ControlLeft / KeyQ / KeyE", "rect": {"x": 16, "y": 268, "width": 128, "height": 128}},
+        {"id": "btn-fire", "label": "Fire", "gameAction": "KeyF", "rect": {"x": 827, "y": 324, "width": 72, "height": 72}},
+        {"id": "btn-yaw-right", "label": "Yaw right", "gameAction": "KeyD", "rect": {"x": 779, "y": 352, "width": 44, "height": 44}},
+        {"id": "btn-collective-down", "label": "Lower collective", "gameAction": "KeyS", "rect": {"x": 755, "y": 276, "width": 44, "height": 44}},
+        {"id": "btn-collective-up", "label": "Raise collective", "gameAction": "KeyW", "rect": {"x": 803, "y": 276, "width": 44, "height": 44}},
+        {"id": "btn-yaw-left", "label": "Yaw left", "gameAction": "KeyA", "rect": {"x": 851, "y": 276, "width": 44, "height": 44}},
+        {"id": "btn-pause", "label": "Pause", "gameAction": "Escape", "rect": {"x": 755, "y": 228, "width": 44, "height": 44}},
+        {"id": "btn-reset", "label": "Reset", "gameAction": "KeyR", "rect": {"x": 803, "y": 228, "width": 44, "height": 44}},
+        {"id": "btn-view", "label": "Change view", "gameAction": "KeyC", "rect": {"x": 851, "y": 228, "width": 44, "height": 44}}
+      ]
+    }
+  ]
+}
__SOLUTION__
