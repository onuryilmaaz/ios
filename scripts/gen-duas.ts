// Dua verisinin Shared/mobile/src/data içindeki kopyasını iOS için JSON'a çevirir.
// RN'deki çeviri fonksiyonları her dil için aynen çalıştırılır; mantık kopyalanmaz.
// Kaynak değişince depo kökünden: bun scripts/gen-duas.ts
import { plugin } from "bun";
import { writeFileSync } from "fs";
import { join } from "path";

const mobileSrc = join(import.meta.dir, "../Shared/mobile/src");
const duasModule = await import(join(mobileSrc, "data/duas.ts"));
const i18nStub = { language: "tr" };
(globalThis as any).__salahI18nStub = i18nStub;

plugin({
  name: "salah-alias",
  setup(build) {
    // `@/i18n` RN'e bağlı (expo-localization); yerine yalnız `language` taşıyan sahte modül.
    build.module("@/i18n", () => ({ exports: { default: (globalThis as any).__salahI18nStub }, loader: "object" }));
    build.module("@/data/duas", () => ({ exports: duasModule, loader: "object" }));
  },
});

const { DUA_SITUATIONS } = duasModule;
const { localizedDuaCategories, duaSituationLabel, duaSituationKeywords } = await import(join(mobileSrc, "data/duas.i18n.ts"));

const out: Record<string, unknown> = {};
for (const lang of ["tr", "en", "ar"]) {
  i18nStub.language = lang;
  out[lang] = {
    categories: localizedDuaCategories(),
    situations: DUA_SITUATIONS.map((s: any) => ({
      key: s.key,
      icon: s.icon,
      duaIds: s.duaIds,
      label: duaSituationLabel(s.key, s.label),
      keywords: duaSituationKeywords(s.key, s.keywords),
    })),
  };
}
const file = join(import.meta.dir, "../Salah/Resources/duas.generated.json");
writeFileSync(file, JSON.stringify(out, null, 2) + "\n");
console.log("yazıldı:", file);
