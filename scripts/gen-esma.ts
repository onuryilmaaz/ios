// Esmaül Hüsna verisinin Shared/mobile/src/data içindeki kopyasını
// iOS için JSON'a çevirir; RN'deki `localizeEsma` her dil için aynen çalıştırılır.
// Kaynak değişince depo kökünden: bun scripts/gen-esma.ts
import { plugin } from "bun";
import { writeFileSync } from "fs";
import { join } from "path";

const mobileSrc = join(import.meta.dir, "../Shared/mobile/src");
plugin({
  name: "salah-alias",
  setup(build) {
    build.onResolve({ filter: /^@\// }, (args) => ({ path: join(mobileSrc, args.path.slice(2)) }));
  },
});

const { ESMAUL_HUSNA, localizeEsma } = await import(join(mobileSrc, "data/esmaulHusna.ts"));
const out: Record<string, unknown> = {};
for (const lang of ["tr", "en", "ar"]) out[lang] = ESMAUL_HUSNA.map((n: any) => localizeEsma(n, lang));

const file = join(import.meta.dir, "../Salah/Resources/esma.generated.json");
writeFileSync(file, JSON.stringify(out, null, 2) + "\n");
console.log("yazıldı:", file);
