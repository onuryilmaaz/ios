# Salah iOS

Salah uygulamasının SwiftUI iOS projesi. Bu depo bağımsız olarak klonlanıp derlenebilir; yanına React Native deposunu koymak gerekmez.

## Açma ve derleme

Xcode 26 ve [XcodeGen](https://github.com/yonaskolb/XcodeGen) gerekir. Depo kökünde:

```sh
xcodegen generate
open Salah.xcodeproj
```

Xcode'da `Salah` şemasını seçin. Debug uygulaması `com.onur6541.salah.dev`, Release uygulaması `com.onur6541.salah` kimliğini kullanır. Gerçek cihaza kurma ve arşiv yükleme için Apple geliştirici takımının imzalama erişimi gerekir. Sürüm/build numarası `project.yml` içindedir; TestFlight'a göndermeden önce benzersiz build numarası seçip `xcodegen generate` komutunu yeniden çalıştırın. Cihaz ve servis kabul adımları için [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) dosyasına bakın.

## Kaynak dosyalar

`Shared/mobile/`, eski React Native projesinden alınmış ve iOS uygulaması ile widget'ların kullandığı Swift kaynaklarının, çevirilerin, veri dosyalarının, seslerin ve ikon kaynaklarının kopyasıdır. Bu dosyalar otomatik eşitlenmez. RN kaynaklarını değiştirirseniz ilgili dosyaları burada da güncelleyin. `project.yml` yalnız bu depo içindeki yolları kullanır.

`Salah.xcodeproj` izlenir ve `project.yml` dosyasından üretilir. Veri veya ikon kaynakları değişirse Bun kurulu bir makinede aşağıdaki betikleri çalıştırıp oluşan dosyaları da commit edin:

```sh
bun scripts/gen-duas.ts
bun scripts/gen-esma.ts
bun scripts/gen-legal.ts
sh scripts/gen-app-icons.sh
xcodegen generate
```

`build/`, DerivedData, arşivler ve kişisel imzalama dosyaları Git'e dahil edilmez. API adresi ve uygulama sürüm ayarları `project.yml` içindedir. Gizli sunucu anahtarları ve `.env` dosyaları bu depoya konmamalıdır.
