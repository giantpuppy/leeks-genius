from PIL import Image, ImageDraw, ImageFont
import os

img = Image.new('RGB', (400, 320), 'white')
draw = ImageDraw.Draw(img)

font_paths = [
    'C:/Windows/Fonts/simhei.ttf',
    'C:/Windows/Fonts/simsun.ttc',
    'C:/Windows/Fonts/msyh.ttc',
]
font = None
for fp in font_paths:
    if os.path.exists(fp):
        try:
            font = ImageFont.truetype(fp, 26)
            print(f'Using font: {fp}')
            break
        except Exception as e:
            print(f'Failed to load {fp}: {e}')

if font is None:
    font = ImageFont.load_default()
    print('Using default font')

draw.text((20, 20), 'Cast List', fill='black', font=font)
draw.text((20, 65), 'Gu Jingwei    Wang Xiaohuan', fill='black', font=font)
draw.text((20, 105), 'Qu Jianxiong  Xu Wenxin', fill='black', font=font)
draw.text((20, 145), 'Ding Xilin    Li Xiaohui', fill='black', font=font)
draw.text((20, 185), 'Jianxiong     Lu Wen', fill='black', font=font)
draw.text((20, 225), 'Jingwei       Lu Fuyang', fill='black', font=font)
img.save('test_cast.jpg')
print('Created test_cast.jpg')
