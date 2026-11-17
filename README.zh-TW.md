# Z-DON Skins

[English](README.md) | 繁體中文

給 [Z-DON](https://github.com/GanYiZhong/Z-DON)（[YataiDON](https://github.com/Yonokid/YataiDON) 的 AI 開發分支）做的
skin。每個 skin 有兩個版本：Z-DON 用的，和上游 YataiDON 用的。兩個版本都需要另外安裝父 skin
YataiDONNijiiro 和 PyTaikoGreen（見[父 skin](#父-skin)）。

| Skin | 風格 |
|---|---|
| **YataiDONSimpleStyle** | 明亮的 8-bit 像素風：淡藍天空下的米色畫面、祭典舞台、黑框白窗，兩個原創像素角色（兔子 Momo 和哈士奇 Hoshi） |
| **YataiDONSimpleStyleDark** | 同一個 skin 的夜晚版：深色視窗、淺色文字、星空。它是 YataiDONSimpleStyle 的子 skin，要兩個一起裝 |

## 要用哪個資料夾

| 資料夾 | 給 | 解析度 |
|---|---|---|
| [`Z-DON/`](Z-DON) | Z-DON | 4K：圖是兩倍大（`screen.texture_density = 2`），各語言的疊加字型 |
| [`YataiDON/`](YataiDON) | 上游 YataiDON（以及其他沒有這兩個功能的引擎） | 1080p，一個包含所有語言的字型 |

兩個版本的版面、圖和腳本都一樣。只有 Z-DON 才有的功能（判定時機面板、歌曲進度、選曲畫面的譜面資訊和最近成績、練習模式的
區段循環、Z-DON 的 AI 對戰、Z-DON 多出來的設定項）在上游就是不顯示：腳本會先確認引擎有沒有這個功能。已經在上游 YataiDON
`602ed8d` 上測過標題、入口、選曲、段位選擇、設定、整首自動演奏到結算、練習模式：全部正常顯示，沒有腳本錯誤。唯一的差別：
圖上直接畫了文字的那些圖（例如設定畫面的標題），上游會顯示日文版，因為上游不會自己去找 `名稱_語言` 的圖。

## 安裝

1. 從 [Releases](https://github.com/GanYiZhong/Z-DON-Skins/releases/latest) 下載最新的 zip：
   [`Z-DON-Skins-Z-DON.zip`](https://github.com/GanYiZhong/Z-DON-Skins/releases/latest/download/Z-DON-Skins-Z-DON.zip)
   或 [`Z-DON-Skins-YataiDON.zip`](https://github.com/GanYiZhong/Z-DON-Skins/releases/latest/download/Z-DON-Skins-YataiDON.zip)。
   `main` 每次更新都會自動重新打包（rolling release）。也可以下載或 clone 整個 repo。
2. 確認遊戲的 `Skins/` 資料夾裡有 `YataiDONNijiiro` 和 `PyTaikoGreen`。
3. 把 zip 解壓出來的（或 repo 的 `Z-DON/`、`YataiDON/` 裡的） `YataiDONSimpleStyle`（要夜晚版就再加 `YataiDONSimpleStyleDark`）複製到遊戲的
   `Skins/` 資料夾。
4. 在遊戲設定裡選這個 skin。

Z-DON 的安裝包已經內附這兩個 skin 的 Z-DON 版；第一次啟動的畫面會下載父 skin。

## 父 skin

YataiDONSimpleStyle 沿用 **YataiDONNijiiro** 的版面和畫面流程，而 YataiDONNijiiro 又建立在 **PyTaikoGreen** 上，
所以這兩個也要安裝（`skin_config.json` 把 `YataiDONNijiiro` 設為父 skin）。它們屬於各自的作者，不放在這個 repo；
請從 [YataiDONNijiiro](https://ese.tjadataba.se/Yonokid/YataiDONNijiiro) 和
[PyTaikoGreen](https://ese.tjadataba.se/Yonokid/PyTaikoGreen) 取得（Z-DON 第一次啟動的畫面會連同父 skin 一起安裝）。

## 重建

- [`generator/`](generator)：畫出 SimpleStyle 每一張圖、寫出它的腳本的 Python 產生器（`python build.py`；
  `--theme dark` 是夜晚配色，`--density 1` 是 1080p）。父 skin 從環境變數 `SS_SKINS`（含 YataiDONNijiiro 和
  PyTaikoGreen 的 `Skins` 資料夾）讀。說明在 `SCREEN_GUIDE_V2.md`、`STYLE_GUIDE.md`、`README_dark.md`。
- [`tools/zdon_standalone_skin.py`](tools/zdon_standalone_skin.py)：從 `Skins` 資料夾複製出一個 skin
  （`--keep-parent`：只有它自己的檔案，不含更新器的記錄檔）。
- [`tools/zdon_skin_upstream.py`](tools/zdon_skin_upstream.py)：把 Z-DON 版轉成上游版（skin 自己的圖和 texture.json
  數字減半，只留基本字型）。

```bash
python tools/zdon_standalone_skin.py <Z-DON>/build/bin/Skins YataiDONSimpleStyle Z-DON --keep-parent
python tools/zdon_skin_upstream.py Z-DON/YataiDONSimpleStyle YataiDON/YataiDONSimpleStyle
```

Z-DON 的安裝包用 `tools/zdon_bundle_simplestyle.sh` 做同樣的事。

## 授權

GPL-3.0，跟 YataiDON 一樣（見 [LICENSE](LICENSE)）：SimpleStyle 的圖、腳本和產生器。SimpleStyle 的圖全部是原創、用程式
產生的。像素字型是 [Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font)，採用 SIL Open Font License 1.1
（`Fonts/OFL.txt`、`Fonts/LICENSES/`）。
