// Outils passés aux étapes et à `connexion` sous `outils`.
import { createHmac } from 'node:crypto';

const base32 = (s) => {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const c of s.replace(/=+$/, '').toUpperCase()) bits += alphabet.indexOf(c).toString(2).padStart(5, '0');
  return Buffer.from(bits.match(/.{8}/g).map((b) => parseInt(b, 2)));
};

// TOTP (RFC 6238, SHA1, 6 chiffres, 30 s), comme ROTP côté Rails.
export const totp = (secret, pas = Math.floor(Date.now() / 30_000)) => {
  const compteur = Buffer.alloc(8);
  compteur.writeBigUInt64BE(BigInt(pas));
  const h = createHmac('sha1', base32(secret)).update(compteur).digest();
  const o = h[h.length - 1] & 0xf;
  return String((h.readUInt32BE(o) & 0x7fffffff) % 1_000_000).padStart(6, '0');
};

// devise-two-factor refuse un code déjà consommé dans la même fenêtre de 30 s
// (consumed_timestep) : on attend la fenêtre suivante quand le secret vient de servir.
const consommes = new Map();
export const codeFrais = async (secret) => {
  let pas = Math.floor(Date.now() / 30_000);
  while (pas <= (consommes.get(secret) ?? -1)) {
    await new Promise((r) => setTimeout(r, 1000));
    pas = Math.floor(Date.now() / 30_000);
  }
  consommes.set(secret, pas);
  return totp(secret, pas);
};
