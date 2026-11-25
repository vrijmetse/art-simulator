import * as THREE from 'three';
import type { ToolMode } from '../core/types';
import type { CharacterMotionState } from '../core/character';

export interface HomekeeperRig {
  group: THREE.Group;
  bodyGroup: THREE.Group;
  head: THREE.Group;
  leftArm: THREE.Group;
  rightArm: THREE.Group;
  leftLeg: THREE.Group;
  rightLeg: THREE.Group;
  lapMesh: THREE.Group;
  pelMesh: THREE.Group;
}

export function createHomekeeperRig(contactShadowTex: THREE.Texture): HomekeeperRig {
  const group = new THREE.Group();
  const bodyGroup = new THREE.Group();
  group.add(bodyGroup);

  const skinMat = new THREE.MeshStandardMaterial({ color: 0xf1c27d, roughness: 0.72 });
  const scarfMat = new THREE.MeshStandardMaterial({ color: 0x81b29a, roughness: 0.8 });
  const tunicMat = new THREE.MeshStandardMaterial({ color: 0xfdf6ec, roughness: 0.85 });
  const apronMat = new THREE.MeshStandardMaterial({ color: 0xe07a5f, roughness: 0.78 });
  const pantsMat = new THREE.MeshStandardMaterial({ color: 0x3d405b, roughness: 0.85 });
  const eyeMat = new THREE.MeshBasicMaterial({ color: 0x22223b });
  const cheekMat = new THREE.MeshBasicMaterial({ color: 0xf4978e });

  // Grounded contact shadow disc (reuses shared texture; zero shadowMap updates)
  const shadowDisc = new THREE.Mesh(
    new THREE.PlaneGeometry(0.56, 0.56),
    new THREE.MeshBasicMaterial({
      map: contactShadowTex,
      transparent: true,
      depthWrite: false,
      opacity: 0.72,
    }),
  );
  shadowDisc.rotation.x = -Math.PI / 2;
  shadowDisc.position.y = 0.005;
  group.add(shadowDisc);

  // Legs
  const leftLeg = new THREE.Group();
  leftLeg.position.set(-0.085, 0.28, 0);
  const legGeo = new THREE.CapsuleGeometry(0.055, 0.16, 4, 8);
  const lLegMesh = new THREE.Mesh(legGeo, pantsMat);
  lLegMesh.position.y = -0.12;
  leftLeg.add(lLegMesh);

  const rightLeg = new THREE.Group();
  rightLeg.position.set(0.085, 0.28, 0);
  const rLegMesh = new THREE.Mesh(legGeo, pantsMat);
  rLegMesh.position.y = -0.12;
  rightLeg.add(rLegMesh);
  bodyGroup.add(leftLeg, rightLeg);

  // Torso + Apron
  const torso = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.17, 0.34, 12), tunicMat);
  torso.position.y = 0.45;
  const apron = new THREE.Mesh(new THREE.BoxGeometry(0.24, 0.30, 0.06), apronMat);
  apron.position.set(0, 0.42, 0.13);
  const pocket = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.10, 0.02), tunicMat);
  pocket.position.set(0, 0.36, 0.165);
  bodyGroup.add(torso, apron, pocket);

  // Head + Cozy Bandana + Friendly Face
  const head = new THREE.Group();
  head.position.set(0, 0.77, 0);
  const headSphere = new THREE.Mesh(new THREE.SphereGeometry(0.165, 16, 14), skinMat);
  const cap = new THREE.Mesh(
    new THREE.SphereGeometry(0.172, 16, 12, 0, Math.PI * 2, 0, Math.PI * 0.58),
    scarfMat,
  );
  cap.position.y = 0.02;
  cap.rotation.x = -0.18;

  const eyeL = new THREE.Mesh(new THREE.SphereGeometry(0.021, 8, 8), eyeMat);
  eyeL.position.set(-0.055, 0.01, 0.148);
  const eyeR = new THREE.Mesh(new THREE.SphereGeometry(0.021, 8, 8), eyeMat);
  eyeR.position.set(0.055, 0.01, 0.148);
  const cheekL = new THREE.Mesh(new THREE.SphereGeometry(0.024, 8, 8), cheekMat);
  cheekL.scale.set(1.2, 0.7, 0.5);
  cheekL.position.set(-0.088, -0.025, 0.138);
  const cheekR = new THREE.Mesh(new THREE.SphereGeometry(0.024, 8, 8), cheekMat);
  cheekR.scale.set(1.2, 0.7, 0.5);
  cheekR.position.set(0.088, -0.025, 0.138);
  head.add(headSphere, cap, eyeL, eyeR, cheekL, cheekR);
  bodyGroup.add(head);

  // Arms
  const armGeo = new THREE.CapsuleGeometry(0.042, 0.16, 4, 8);
  const leftArm = new THREE.Group();
  leftArm.position.set(-0.19, 0.56, 0);
  const lArmMesh = new THREE.Mesh(armGeo, tunicMat);
  lArmMesh.position.y = -0.1;
  leftArm.add(lArmMesh);

  const rightArm = new THREE.Group();
  rightArm.position.set(0.19, 0.56, 0);
  const rArmMesh = new THREE.Mesh(armGeo, tunicMat);
  rArmMesh.position.y = -0.1;
  rightArm.add(rArmMesh);

  // Handheld Tool 1: Lap (folded microfiber cloth)
  const lapMesh = new THREE.Group();
  lapMesh.position.set(0, -0.22, 0.06);
  const cloth = new THREE.Mesh(
    new THREE.BoxGeometry(0.14, 0.045, 0.14),
    new THREE.MeshStandardMaterial({ color: 0x48cae4, roughness: 0.7 }),
  );
  lapMesh.add(cloth);
  rightArm.add(lapMesh);

  // Handheld Tool 2: Pel (wooden handle + mop fringe head)
  const pelMesh = new THREE.Group();
  pelMesh.position.set(0, -0.21, 0.06);
  const stick = new THREE.Mesh(
    new THREE.CylinderGeometry(0.018, 0.018, 0.68, 8),
    new THREE.MeshStandardMaterial({ color: 0xd4a373, roughness: 0.7 }),
  );
  stick.rotation.x = Math.PI * 0.25;
  stick.position.set(0, -0.06, 0.16);
  const mopHead = new THREE.Mesh(
    new THREE.BoxGeometry(0.24, 0.06, 0.12),
    new THREE.MeshStandardMaterial({ color: 0xfaf3e0, roughness: 0.85 }),
  );
  mopHead.position.set(0, -0.30, 0.36);
  pelMesh.add(stick, mopHead);
  pelMesh.visible = false;
  rightArm.add(pelMesh);

  bodyGroup.add(leftArm, rightArm);

  group.traverse((obj) => {
    if ((obj as THREE.Mesh).isMesh) {
      obj.castShadow = false;
      obj.receiveShadow = false;
    }
  });

  return {
    group,
    bodyGroup,
    head,
    leftArm,
    rightArm,
    leftLeg,
    rightLeg,
    lapMesh,
    pelMesh,
  };
}

export function applyHomekeeperPose(
  rig: HomekeeperRig,
  state: CharacterMotionState,
  toolMode: ToolMode,
): void {
  rig.group.position.set(state.x, 0, state.z);
  rig.group.rotation.y = state.rotY;

  rig.lapMesh.visible = toolMode === 'lap';
  rig.pelMesh.visible = toolMode === 'pel';

  // Reset defaults
  rig.bodyGroup.position.y = 0;
  rig.bodyGroup.rotation.x = 0;
  rig.head.rotation.z = 0;
  rig.leftLeg.rotation.x = 0;
  rig.rightLeg.rotation.x = 0;
  rig.leftArm.rotation.x = 0;
  rig.leftArm.rotation.z = 0.08;
  rig.rightArm.rotation.x = -0.22;
  rig.rightArm.rotation.z = -0.08;

  if (state.pose === 'walk') {
    const s = Math.sin(state.animTime * 11);
    rig.leftLeg.rotation.x = s * 0.55;
    rig.rightLeg.rotation.x = -s * 0.55;
    rig.leftArm.rotation.x = -s * 0.45;
    rig.rightArm.rotation.x = s * 0.35 - 0.25;
    rig.bodyGroup.position.y = Math.abs(s) * 0.035;
  } else if (state.pose === 'scrub') {
    const s = Math.sin(state.animTime * 16);
    rig.bodyGroup.rotation.x = 0.16;
    rig.rightArm.rotation.x = -0.95 + s * 0.28;
    rig.rightArm.rotation.z = s * 0.32;
    rig.leftArm.rotation.x = -0.35;
  } else if (state.pose === 'celebrate') {
    const hop = Math.abs(Math.sin(state.animTime * 9));
    rig.bodyGroup.position.y = hop * 0.18;
    rig.leftArm.rotation.z = 2.4 + Math.sin(state.animTime * 12) * 0.25;
    rig.rightArm.rotation.z = -2.4 - Math.sin(state.animTime * 12) * 0.25;
    rig.head.rotation.z = Math.sin(state.animTime * 6) * 0.12;
  }
}

export function disposeHomekeeperRig(rig: HomekeeperRig): void {
  rig.group.traverse((obj) => {
    if ((obj as THREE.Mesh).isMesh) {
      const m = obj as THREE.Mesh;
      m.geometry?.dispose();
      const mats = Array.isArray(m.material) ? m.material : [m.material];
      for (const mat of mats) {
        mat?.dispose();
      }
    }
  });
}
