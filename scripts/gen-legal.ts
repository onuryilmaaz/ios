// Yasal metinlerin Shared/mobile/src/constants/legal.ts kopyasını iOS için JSON'a çevirir.
// Kaynak değişince depo kökünden: bun scripts/gen-legal.ts
import { writeFileSync } from "fs";
import { join } from "path";
import { LEGAL } from "../Shared/mobile/src/constants/legal";

const out = join(import.meta.dir, "../Salah/Resources/legal.generated.json");
writeFileSync(out, JSON.stringify(LEGAL, null, 2) + "\n");
console.log("yazıldı:", out);
