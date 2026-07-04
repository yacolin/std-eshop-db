#!/usr/bin/env python3
"""
为新表（sp_ / tx_ / mkt_）批量生成测试数据。

用法：
    python sql/seed/seed_test_data.py                   # 生成全部
    python sql/seed/seed_test_data.py --clean            # 先清空再生成
    python sql/seed/seed_test_data.py --module product   # 只生成商品域

依赖：
    pip install pymysql
"""
import os
import random
import sys
import hashlib
import argparse
from datetime import datetime, timedelta

import pymysql

random.seed(42)
FMT = "%Y-%m-%d %H:%M:%S"

MYSQL_CFG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", 3306)),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", "123456"),
    "database": os.getenv("DB_NAME", "eshop_db"),
    "charset": "utf8mb4",
}

# ── 测试数据 ──────────────────────────────────────

BRANDS = [
    ("Apple", "苹果", "A"), ("Samsung", "三星", "S"), ("Xiaomi", "小米", "X"),
    ("Huawei", "华为", "H"), ("OPPO", "OPPO", "O"), ("Vivo", "vivo", "V"),
    ("Sony", "索尼", "S"), ("Lenovo", "联想", "L"), ("Dell", "戴尔", "D"),
    ("HP", "惠普", "H"), ("Asus", "华硕", "A"), ("Nike", "耐克", "N"),
    ("Adidas", "阿迪达斯", "A"), ("Uniqlo", "优衣库", "U"), ("Zara", "飒拉", "Z"),
    ("H&M", "海恩斯莫里斯", "H"), ("Lululemon", "露露乐蒙", "L"), ("New Balance", "新百伦", "N"),
    ("Converse", "匡威", "C"), ("Vans", "范斯", "V"), ("Supreme", "至尊", "S"),
    ("Starbucks", "星巴克", "S"), ("Coca-Cola", "可口可乐", "C"), ("Pepsi", "百事", "P"),
    ("Nestle", "雀巢", "N"), ("L'Oreal", "欧莱雅", "L"), ("Estee Lauder", "雅诗兰黛", "E"),
    ("Dior", "迪奥", "D"), ("Chanel", "香奈儿", "C"), ("Gucci", "古驰", "G"),
    ("Prada", "普拉达", "P"), ("Louis Vuitton", "路易威登", "L"),
]

CATEGORIES = [
    (0, "电子产品", 1), (0, "服装鞋帽", 1), (0, "食品饮料", 1),
    (0, "美妆护肤", 1), (0, "家居生活", 1), (0, "运动户外", 1),
    (0, "图书文具", 1), (0, "汽车用品", 1), (0, "母婴玩具", 1), (0, "宠物用品", 1),
    (1, "手机通讯", 2), (1, "电脑办公", 2), (1, "数码配件", 2),
    (1, "智能设备", 2), (1, "影音娱乐", 2),
    (2, "男装", 2), (2, "女装", 2), (2, "童装", 2),
    (2, "运动鞋", 2), (2, "休闲鞋", 2), (2, "箱包皮具", 2),
    (3, "休闲零食", 2), (3, "粮油调味", 2), (3, "饮料冲调", 2),
    (3, "进口食品", 2), (3, "生鲜果蔬", 2),
    (4, "面部护肤", 2), (4, "彩妆", 2), (4, "香水", 2),
    (4, "美发造型", 2), (4, "身体护理", 2),
    (6, "运动器材", 2), (6, "户外装备", 2), (6, "骑行用品", 2),
    (11, "智能手机", 3), (11, "功能机", 3), (11, "对讲机", 3),
    (12, "笔记本", 3), (12, "平板电脑", 3), (12, "台式机", 3),
    (12, "显示器", 3), (12, "打印机", 3),
    (13, "手机壳", 3), (13, "充电器", 3), (13, "数据线", 3),
    (13, "耳机", 3), (13, "移动电源", 3),
    (16, "T恤", 3), (16, "衬衫", 3), (16, "外套", 3),
    (16, "牛仔裤", 3), (16, "西服", 3),
    (17, "连衣裙", 3), (17, "上衣", 3), (17, "半身裙", 3),
    (17, "外套", 3), (17, "毛衣", 3),
    (19, "跑步鞋", 3), (19, "篮球鞋", 3), (19, "休闲鞋", 3),
    (23, "膨化食品", 3), (23, "糖果巧克力", 3), (23, "饼干糕点", 3),
    (28, "洁面", 3), (28, "爽肤水", 3), (28, "精华", 3),
    (28, "面霜", 3), (28, "防晒", 3),
    (29, "粉底", 3), (29, "口红", 3), (29, "眼影", 3),
    (29, "腮红", 3), (29, "睫毛膏", 3),
]

ATTRS = [
    # ── Level 1 ─────────────────────────────────────
    (1, "品牌", 1, None, 0, 1), (1, "保修期", 2, '["1年","2年","3年"]', 0, 0),
    (2, "品牌", 1, None, 0, 1), (2, "适用人群", 2, '["男","女","中性","儿童"]', 0, 0),
    (3, "品牌", 1, None, 0, 1), (3, "保质期", 2, '["3个月","6个月","12个月","18个月"]', 0, 0),
    (4, "品牌", 1, None, 0, 1), (4, "适用肤质", 2, '["油性","干性","混合","敏感","所有肤质"]', 0, 0),
    (5, "品牌", 1, None, 0, 1), (5, "材质", 1, None, 0, 0),
    (6, "品牌", 1, None, 0, 1), (6, "适用季节", 2, '["春","夏","秋","冬","四季"]', 0, 0),
    (7, "品牌", 1, None, 0, 1), (7, "规格", 1, None, 0, 0),
    (8, "品牌", 1, None, 0, 1), (8, "材质", 1, None, 0, 0),
    (9, "品牌", 1, None, 0, 1), (9, "适用年龄", 2, '["0-6个月","6-12个月","1-3岁","3-6岁","6岁以上"]', 0, 0),
    (10, "品牌", 1, None, 0, 1), (10, "适用宠物", 2, '["狗","猫","鱼","鸟","小宠"]', 0, 0),
    # ── Level 2 ─────────────────────────────────────
    (11, "网络制式", 2, '["4G全网通","5G全网通"]', 0, 0),
    (12, "操作系统", 2, '["Windows","macOS","Linux","国产系统"]', 0, 0),
    (13, "适用设备", 1, None, 0, 0),
    (14, "连接方式", 2, '["WiFi","蓝牙","4G","5G"]', 0, 0),
    (15, "连接方式", 2, '["有线","蓝牙","WiFi"]', 0, 0),
    (16, "适用季节", 2, '["春","夏","秋","冬"]', 0, 0),
    (17, "适用季节", 2, '["春","夏","秋","冬"]', 0, 0),
    (18, "适用年龄", 2, '["0-6个月","6-12个月","1-3岁","3-6岁","6岁以上"]', 0, 0),
    (19, "适用场地", 2, '["室内","室外","跑道","越野"]', 0, 0),
    (21, "材质", 1, None, 0, 0),
    (22, "口味", 2, '["原味","番茄味","麻辣味","烧烤味","海苔味"]', 0, 0),
    (25, "原产地", 1, None, 0, 0),
    (26, "产地", 1, None, 0, 0),
    (29, "香型", 2, '["花香","果香","木质香","海洋调","东方调"]', 0, 0),
    (32, "适用场地", 2, '["室内","室外","室内外通用"]', 0, 0),
    (33, "适用季节", 2, '["春","夏","秋","冬"]', 0, 0),
    (34, "材质", 1, None, 0, 0),
    # ── Level 3（叶子分类，保持原样）───────────────
    (35, "颜色", 2, '["黑色","白色","银色","金色","红色","蓝色","紫色","绿色"]', 1, 1),
    (35, "存储容量", 4, '["64G","128G","256G","512G","1T"]', 1, 1),
    (35, "运行内存", 4, '["4G","6G","8G","12G","16G","24G"]', 1, 1),
    (35, "屏幕尺寸", 4, '["5.5","6.1","6.5","6.7","6.9","7.0"]', 0, 0),
    (35, "处理器", 1, None, 0, 0), (35, "后置摄像头", 1, None, 0, 0),
    (35, "电池容量", 4, '["3000","4000","5000","6000","7000"]', 0, 0),
    (38, "颜色", 2, '["银色","深空灰","金色","黑色","白色"]', 1, 1),
    (38, "内存", 4, '["8G","16G","32G","64G"]', 1, 1),
    (38, "硬盘", 4, '["256G SSD","512G SSD","1T SSD","2T SSD"]', 1, 1),
    (38, "屏幕尺寸", 4, '["13.3","14","15.6","16","17.3"]', 0, 0),
    (38, "处理器型号", 1, None, 0, 0), (38, "显卡型号", 1, None, 0, 0),
    (46, "颜色", 2, '["黑色","白色","银色","金色","蓝色","红色"]', 1, 1),
    (46, "连接方式", 2, '["有线","蓝牙","双模"]', 1, 1),
    (46, "降噪", 2, '["主动降噪","被动降噪","无降噪"]', 0, 0),
    (48, "颜色", 2, '["黑色","白色","红色","蓝色","绿色","黄色","粉色","灰色","卡其"]', 1, 1),
    (48, "尺码", 2, '["S","M","L","XL","XXL","XXXL"]', 1, 1),
    (48, "面料", 1, None, 0, 0),
    (53, "颜色", 2, '["黑色","白色","红色","蓝色","绿色","黄色","粉色","灰色","卡其"]', 1, 1),
    (53, "尺码", 2, '["S","M","L","XL","XXL"]', 1, 1),
    (53, "面料", 1, None, 0, 0),
    (58, "颜色", 2, '["黑色","白色","红色","蓝色","绿色","灰色","荧光黄"]', 1, 1),
    (58, "尺码", 2, '["36","37","38","39","40","41","42","43","44","45"]', 1, 1),
    (70, "色号", 2, '["#001 象牙白","#002 自然色","#003 小麦色","#004 粉调白"]', 1, 1),
    (70, "质地", 2, '["哑光","水润","雾面","奶油肌"]', 0, 0),
]

PRODUCTS_PER_CATEGORY = 25

CATEGORY_PROD_CFG = {
    35: (range(1, 7), (199900, 999900), "台",
         ["{b}旗舰手机", "{b}智能手机", "{b}Pro 机型", "{b}轻旗舰", "{b}性能版",
          "{b}Ultra 版", "{b}Plus 版", "{b}e 青春版"],
         ["5G旗舰", "AI智能", "高性能", "超清影像", "长续航", "轻薄设计"]),
    36: (range(1, 7), (9900, 29900), "台",
         ["{b}老年机", "{b}功能手机", "{b}按键手机"], ["大字体", "长续航", "超长待机", "简易操作"]),
    37: (range(7, 12), (19900, 89900), "台",
         ["{b}对讲机", "{b}专业对讲机", "{b}远距离对讲机"], ["远距离", "防水防尘", "长续航", "清晰通话"]),
    38: (range(1, 12), (399900, 1999900), "台",
         ["{b}笔记本", "{b}轻薄本", "{b}商务本", "{b}性能本", "{b}创作本", "{b}电竞本", "{b}Ultrabook"],
         ["高性能", "轻薄便携", "商务办公", "游戏电竞", "创意设计"]),
    39: (range(1, 6), (199900, 999900), "台",
         ["{b}平板电脑", "{b}旗舰平板", "{b}轻薄平板", "{b}学习平板"], ["影音娱乐", "移动办公", "学习教育", "创作绘画"]),
    40: (range(7, 12), (299900, 999900), "台",
         ["{b}台式机", "{b}一体机", "{b}家用台式机", "{b}办公台式机"], ["高性价比", "商务办公", "家用娱乐", "设计制图"]),
    41: (range(7, 12), (99900, 499900), "台",
         ["{b}显示器", "{b}显示器 2K", "{b}显示器 4K", "{b}曲面显示器", "{b}电竞显示器"], ["高清显示", "护眼", "高刷", "专业色准"]),
    42: (range(9, 12), (29900, 199900), "台",
         ["{b}打印机", "{b}彩色打印机", "{b}激光打印机", "{b}多功能一体机"], ["家用打印", "办公高效", "无线打印", "彩色打印"]),
    43: (range(1, 6), (1900, 12900), "个",
         ["{b}手机壳", "{b}保护壳", "{b}透明手机壳", "{b}硅胶手机壳"], ["防摔保护", "轻薄", "高颜值", "简约设计"]),
    44: (range(1, 6), (2900, 19900), "个",
         ["{b}充电器", "{b}快充头", "{b}氮化镓充电器", "{b}无线充电器"], ["快充", "氮化镓", "多口输出", "安全充电"]),
    45: (range(1, 6), (900, 5900), "条",
         ["{b}数据线", "{b}Type-C数据线", "{b}快充数据线", "{b}编织数据线"], ["快充传输", "耐用编织", "加长版", "磁吸收纳"]),
    46: (range(1, 8), (59900, 439900), "副",
         ["{b}无线耳机", "{b}降噪耳机", "{b}头戴式耳机", "{b}运动耳机", "{b}TWS耳机", "{b}入耳式耳机"],
         ["主动降噪", "Hi-Fi音质", "长续航", "舒适佩戴"]),
    47: (range(1, 8), (49900, 199900), "个",
         ["{b}移动电源", "{b}充电宝", "{b}快充移动电源", "{b}大容量充电宝"], ["大容量", "快充", "轻薄便携", "安全电芯"]),
    48: (range(12, 18), (5900, 39900), "件",
         ["{b}T恤", "{b}短袖T恤", "{b}基础款T恤", "{b}印花T恤", "{b}纯棉T恤", "{b}运动T恤"],
         ["舒适纯棉", "透气速干", "基础百搭", "休闲运动"]),
    49: (range(12, 18), (9900, 59900), "件",
         ["{b}衬衫", "{b}长袖衬衫", "{b}短袖衬衫", "{b}商务衬衫", "{b}休闲衬衫"], ["免烫", "修身版型", "商务休闲", "舒适面料"]),
    50: (range(12, 18), (19900, 99900), "件",
         ["{b}外套", "{b}夹克", "{b}风衣", "{b}休闲外套", "{b}棉服"], ["春秋款", "防风保暖", "休闲百搭", "轻薄便携"]),
    51: (range(12, 18), (14900, 79900), "条",
         ["{b}牛仔裤", "{b}直筒牛仔裤", "{b}修身牛仔裤", "{b}宽松牛仔裤"], ["经典款", "弹力舒适", "复古水洗", "百搭"]),
    52: (range(7, 12), (29900, 199900), "套",
         ["{b}西服", "{b}西装", "{b}正装西服", "{b}商务西服"], ["修身版型", "商务正装", "羊毛混纺", "婚礼西服"]),
    53: (range(14, 18), (14900, 69900), "件",
         ["{b}连衣裙", "{b}碎花连衣裙", "{b}通勤连衣裙", "{b}针织连衣裙", "{b}吊带连衣裙", "{b}衬衫裙"],
         ["浪漫清新", "优雅通勤", "舒适修身", "夏日清爽"]),
    54: (range(14, 18), (9900, 49900), "件",
         ["{b}上衣", "{b}针织衫", "{b}雪纺衫", "{b}卫衣", "{b}打底衫"], ["百搭款", "舒适面料", "时尚设计", "春秋穿搭"]),
    55: (range(14, 18), (14900, 39900), "条",
         ["{b}半身裙", "{b}A字裙", "{b}百褶裙", "{b}包臀裙", "{b}牛仔裙"], ["显瘦版型", "高腰设计", "优雅气质", "休闲百搭"]),
    56: (range(14, 18), (19900, 89900), "件",
         ["{b}女装外套", "{b}风衣", "{b}毛呢外套", "{b}牛仔外套", "{b}小香风外套"], ["春秋外套", "百搭款", "气质通勤", "保暖时尚"]),
    57: (range(14, 18), (14900, 59900), "件",
         ["{b}毛衣", "{b}针织毛衣", "{b}羊毛衫", "{b}开衫毛衣", "{b}高领毛衣"], ["柔软保暖", "舒适羊毛", "百搭基础", "时尚宽松"]),
    58: (range(12, 21), (49900, 189900), "双",
         ["{b}跑鞋", "{b}运动鞋", "{b}缓震跑鞋", "{b}训练鞋", "{b}复古跑鞋", "{b}越野跑鞋"],
         ["缓震", "轻量", "稳定支撑", "透气"]),
    59: (range(12, 21), (59900, 159900), "双",
         ["{b}篮球鞋", "{b}实战篮球鞋", "{b}篮球文化鞋"], ["缓震回弹", "包裹支撑", "耐磨防滑", "实战利器"]),
    60: (range(12, 21), (29900, 99900), "双",
         ["{b}休闲鞋", "{b}板鞋", "{b}帆布鞋", "{b}滑板鞋", "{b}德训鞋"], ["经典百搭", "复古风格", "舒适脚感", "日常穿着"]),
    61: (range(22, 24), (990, 2990), "袋",
         ["{b}薯片", "{b}膨化食品", "{b}虾条", "{b}米饼", "{b}爆米花"], ["香脆可口", "多味装", "休闲零食", "分享装"]),
    62: (range(22, 24), (990, 3990), "盒",
         ["{b}巧克力", "{b}糖果", "{b}棒棒糖", "{b}软糖", "{b}夹心巧克力"], ["丝滑口感", "纯可可脂", "精美包装", "礼盒装"]),
    63: (range(22, 24), (990, 2990), "袋",
         ["{b}饼干", "{b}曲奇", "{b}蛋卷", "{b}威化饼干", "{b}夹心饼干"], ["酥脆", "独立包装", "早餐搭档", "休闲时光"]),
    64: (range(24, 30), (1900, 19900), "支",
         ["{b}洁面乳", "{b}洗面奶", "{b}洁面泡沫", "{b}卸妆洁面"], ["温和清洁", "深层洁净", "保湿", "控油祛痘"]),
    65: (range(24, 30), (2900, 29900), "瓶",
         ["{b}爽肤水", "{b}柔肤水", "{b}化妆水", "{b}收敛水"], ["补水保湿", "舒缓", "收缩毛孔", "清爽"]),
    66: (range(24, 30), (4900, 59900), "瓶",
         ["{b}精华液", "{b}精华露", "{b}美白精华", "{b}抗皱精华", "{b}保湿精华"], ["抗衰老", "美白淡斑", "深层保湿", "修复肌肤"]),
    67: (range(24, 30), (2900, 49900), "瓶",
         ["{b}面霜", "{b}保湿面霜", "{b}抗皱面霜", "{b}修复面霜", "{b}日霜"], ["深层滋润", "抗皱紧致", "修护屏障", "清爽不腻"]),
    68: (range(24, 30), (2900, 39900), "支",
         ["{b}防晒霜", "{b}防晒乳", "{b}防晒喷雾", "{b}隔离防晒"], ["SPF50+", "PA+++", "清爽不油腻", "防水持久"]),
    69: (range(24, 30), (3900, 39900), "盒",
         ["{b}粉底液", "{b}气垫", "{b}粉饼", "{b}BB霜", "{b}CC霜"], ["自然遮瑕", "水润服帖", "持妆长久", "轻薄透气"]),
    70: (range(24, 30), (9900, 49900), "支",
         ["{b}口红", "{b}唇膏", "{b}唇釉", "{b}唇泥", "{b}唇彩"], ["哑光", "水润", "丝绒", "雾面", "奶油肌"]),
    71: (range(24, 30), (2900, 29900), "盒",
         ["{b}眼影盘", "{b}单色眼影", "{b}眼影笔", "{b}液体眼影"], ["大地色系", "粉棕系", "哑光", "珠光闪粉"]),
    72: (range(24, 30), (1900, 19900), "盒",
         ["{b}腮红", "{b}腮红盘", "{b}液体腮红", "{b}腮红膏"], ["自然显色", "粉嫩", "修容", "元气妆"]),
    73: (range(24, 30), (1900, 19900), "支",
         ["{b}睫毛膏", "{b}睫毛打底", "{b}纤长睫毛膏", "{b}浓密睫毛膏"], ["卷翘纤长", "浓密", "防水不晕", "自然裸感"]),
}


def generate_products():
    products = []
    used_names = set()
    suffix_idx = 0
    for cat_idx, cfg in CATEGORY_PROD_CFG.items():
        brand_range, price_range, unit, name_tpls, sub_tpls = cfg
        brands = list(brand_range)
        for i in range(PRODUCTS_PER_CATEGORY):
            brand = random.choice(brands)
            name_tpl = random.choice(name_tpls)
            sub_tpl = random.choice(sub_tpls)
            brand_name = BRANDS[brand - 1][1]
            name = name_tpl.format(b=brand_name)
            while name in used_names:
                suffix_idx += 1
                name = f"{name_tpl.format(b=brand_name)} {suffix_idx}"
            used_names.add(name)
            price_min = price_range[0]
            price_max = price_range[1]
            price = random.randint(price_min, price_max)
            market_price = int(price * random.uniform(1.1, 1.3))
            products.append((name, sub_tpl, cat_idx, brand, price, market_price, unit))
    return products


_GENERATED_PRODUCTS = None

COLORS = ["黑色", "白色", "银色", "金色", "红色", "蓝色", "紫色", "绿色", "粉色", "灰色", "卡其", "荧光黄"]
STORAGES = ["64G", "128G", "256G", "512G", "1T"]
RAMS = ["4G", "6G", "8G", "12G", "16G", "24G"]
LIPSTICK_SHADES = ["#001 经典红", "#002 豆沙粉", "#003 橘红", "#004 玫红", "#005 奶茶色", "#006 复古红"]
CLOTHES_SIZES = ["S", "M", "L", "XL", "XXL", "XXXL"]
SHOE_SIZES = ["36", "37", "38", "39", "40", "41", "42", "43", "44", "45"]


def generate_spec(category_id):
    if category_id == 35:
        color = random.choice(COLORS[:8])
        storage = random.choice(STORAGES[:4])
        ram = random.choice(RAMS[:5])
        return f'{{"颜色":"{color}","存储容量":"{storage}","运行内存":"{ram}"}}', {"color": color, "storage": storage, "ram": ram}
    elif category_id == 38:
        color = random.choice(["银色", "深空灰", "金色", "黑色"])
        ram = random.choice(["8G", "16G", "32G"])
        disk = random.choice(["256G SSD", "512G SSD", "1T SSD"])
        return f'{{"颜色":"{color}","内存":"{ram}","硬盘":"{disk}"}}', {"color": color, "ram": ram, "disk": disk}
    elif category_id == 46:
        color = random.choice(COLORS[:6])
        connect = random.choice(["蓝牙", "有线", "双模"])
        return f'{{"颜色":"{color}","连接方式":"{connect}"}}', {"color": color, "connect": connect}
    elif category_id in [48, 53]:
        color = random.choice(COLORS[:10])
        size = random.choice(CLOTHES_SIZES)
        return f'{{"颜色":"{color}","尺码":"{size}"}}', {"color": color, "size": size}
    elif category_id in [58, 59, 60]:
        color = random.choice(COLORS[:8])
        size = random.choice(SHOE_SIZES)
        return f'{{"颜色":"{color}","尺码":"{size}"}}', {"color": color, "size": size}
    elif category_id in [49, 50, 51, 52, 56, 57]:
        color = random.choice(COLORS[:8])
        size = random.choice(CLOTHES_SIZES)
        return f'{{"颜色":"{color}","尺码":"{size}"}}', {"color": color, "size": size}
    elif category_id in [61, 62, 63]:
        flavor = random.choice(["原味", "番茄味", "麻辣味", "烧烤味", "海苔味"])
        return f'{{"口味":"{flavor}"}}', {"flavor": flavor}
    elif category_id in [64, 68]:
        spec_type = random.choice(["清爽型", "滋润型", "敏感肌用"])
        return f'{{"类型":"{spec_type}","容量":"{random.choice(["100ml","150ml","200ml"])}"}}', {"type": spec_type}
    elif category_id in [65, 66, 67]:
        spec_type = random.choice(["清爽型", "滋润型", "修护型"])
        capacity = random.choice(["30ml", "50ml", "100ml", "120ml"])
        return f'{{"类型":"{spec_type}","容量":"{capacity}"}}', {"type": spec_type, "capacity": capacity}
    elif category_id in [69, 71, 72, 73]:
        shade = random.choice(["自然色", "象牙白", "小麦色", "粉调"])
        return f'{{"色号":"{shade}"}}', {"shade": shade}
    elif category_id == 70:
        shade = random.choice(LIPSTICK_SHADES[:6])
        texture = random.choice(["哑光", "水润", "雾面", "奶油肌"])
        return f'{{"色号":"{shade}","质地":"{texture}"}}', {"shade": shade, "texture": texture}
    else:
        color = random.choice(COLORS[:6])
        return f'{{"颜色":"{color}"}}', {"color": color}


def connect():
    try:
        conn = pymysql.connect(**MYSQL_CFG)
        print("MySQL connected")
        return conn
    except Exception as e:
        print(f"MySQL 连接失败: {e}")
        sys.exit(1)


def clean(conn):
    tables = [
        "mch_settlement_details", "mch_merchant_settlement_logs", "mch_merchant_withdrawals",
        "mch_merchant_balances", "mch_merchant_users", "mch_merchant_qualifications",
        "mch_merchant_bank_accounts", "mch_merchant_contacts", "mch_merchants",
        "mkt_promotion_usage_logs", "mkt_user_promotions", "mkt_promotion_products",
        "mkt_promotion_rules", "mkt_promotions",
        "tx_refunds", "tx_payment_logs", "tx_payments",
        "tx_order_logs", "tx_order_items", "tx_orders", "tx_sub_orders",
        "tx_cart_items", "tx_carts",
        "tx_after_sale_evidences", "tx_after_sale_logs", "tx_after_sales",
        "sp_inventory_logs", "sp_inventories", "sp_product_versions",
        "sp_product_attributes", "sp_product_descriptions", "sp_skus",
        "sp_products", "sp_attributes", "sp_category_brands", "sp_categories", "sp_brands",
        "usr_addresses", "usr_points", "usr_levels",
        "tx_delivery_traces", "tx_delivery_items", "tx_deliveries",
        "base_notification_reads", "base_notifications", "base_notification_templates",
    ]
    with conn.cursor() as cur:
        cur.execute("SET FOREIGN_KEY_CHECKS = 0")
        for t in tables:
            cur.execute(f"TRUNCATE TABLE {t}")
        cur.execute("SET FOREIGN_KEY_CHECKS = 1")
    conn.commit()
    print("已清空所有新表\n")


# ── 商品中心 ──────────────────────────────────────

def seed_product(conn):
    global _GENERATED_PRODUCTS
    if _GENERATED_PRODUCTS is None:
        _GENERATED_PRODUCTS = generate_products()
        print(f"  自动生成 SPU: {len(_GENERATED_PRODUCTS)} 个")
    products = _GENERATED_PRODUCTS

    with conn.cursor() as cur:
        brand_id_map = {}
        for name, cname, letter in BRANDS:
            cur.execute(
                "INSERT INTO sp_brands (name, english_name, first_letter, sort_order, status) "
                "VALUES (%s, %s, %s, %s, 1)",
                (cname, name, letter, random.randint(1, 100)),
            )
            brand_id_map[(cname, name)] = cur.lastrowid
        print(f"  品牌: {len(BRANDS)}")

        cat_ids = {}
        for i, (parent_id, name, level) in enumerate(CATEGORIES, 1):
            path = ""
            if parent_id > 0:
                parent_id_actual = cat_ids.get(parent_id)
                if parent_id_actual:
                    cur.execute("SELECT path FROM sp_categories WHERE id = %s", (parent_id_actual,))
                    row = cur.fetchone()
                    if row:
                        path = row[0] + str(parent_id_actual) + "/"
            cur.execute(
                "INSERT INTO sp_categories (name, parent_id, level, path, sort_order, status) "
                "VALUES (%s, %s, %s, %s, %s, 1)",
                (name, parent_id if parent_id == 0 else cat_ids.get(parent_id, 0), level, path, i * 10),
            )
            cat_ids[i] = cur.lastrowid
        print(f"  类目: {len(CATEGORIES)}")

        attr_map = {}
        for cat_idx, name, input_type, values, is_sku, searchable in ATTRS:
            cur.execute(
                "INSERT INTO sp_attributes (name, category_id, input_type, `values`, is_sku_spec, searchable, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, 1)",
                (name, cat_ids[cat_idx], input_type, values, is_sku, searchable),
            )
            attr_map[(cat_idx, name)] = cur.lastrowid
        print(f"  属性: {len(ATTRS)}")

        total_skus = 0
        product_count = 0
        for name, subtitle, cat_idx, brand_idx, price, market, unit in products:
            brand_id = brand_idx
            cur.execute(
                "INSERT INTO sp_products (name, subtitle, category_id, brand_id, unit, main_image, "
                "min_price, max_price, status) "
                "VALUES (%s, %s, %s, %s, %s, '', %s, %s, 2)",
                (name, subtitle, cat_ids[cat_idx], brand_id, unit, price, market),
            )
            spu_id = cur.lastrowid
            product_count += 1

            sku_count = random.randint(2, 6)
            generated_specs = set()
            for j in range(sku_count):
                spec_json, spec_dict = generate_spec(cat_idx)
                if spec_json in generated_specs:
                    color = random.choice(COLORS[:8])
                    if "颜色" in spec_dict:
                        spec_dict["颜色"] = color
                    spec_json = '{"' + '","'.join([f'{k}":"{v}' for k, v in spec_dict.items()]) + '"}'
                    if spec_json in generated_specs:
                        continue
                generated_specs.add(spec_json)

                sku_price = price + random.randint(-int(price * 0.2), int(price * 0.3))
                sku_price = max(price - int(price * 0.3), sku_price)
                sku_code = f"SKU{spu_id}-{j+1:03d}"
                barcode = f"{random.randint(1000000000000, 9999999999999)}"
                spec_signature = hashlib.md5(spec_json.encode()).hexdigest()
                cur.execute(
                    "INSERT INTO sp_skus (product_id, sku_code, barcode, spec, spec_signature, price, market_price, cost_price, status) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 1)",
                    (spu_id, sku_code, barcode, spec_json, spec_signature, sku_price,
                     sku_price + random.randint(int(sku_price * 0.1), int(sku_price * 0.3)),
                     int(sku_price * 0.6)),
                )
                total_skus += 1

            has_desc = 0
            if random.random() < 0.7:
                desc_text = f"{name}是一款优质的{subtitle}产品，给您带来极致体验。采用高品质材料，精心打造每一个细节。"
                mobile_text = f"<h1>{name}</h1><p>{subtitle}，{desc_text}</p>"
                cur.execute(
                    "INSERT INTO sp_product_descriptions (product_id, description, mobile_description) "
                    "VALUES (%s, %s, %s)",
                    (spu_id, desc_text, mobile_text),
                )
                has_desc = 1
            if has_desc == 1:
                cur.execute("UPDATE sp_products SET has_description = 1 WHERE id = %s", (spu_id,))

            for (a_cat_idx, attr_name), attr_id in attr_map.items():
                if a_cat_idx == cat_idx:
                    val = random.choice(["标准", "优质", "普通", "高级", "入门"])
                    if attr_name in ["颜色", "色号"]:
                        val = random.choice(["黑色", "白色", "红色", "蓝色"])
                    elif attr_name in ["面料", "材质", "处理器型号", "显卡型号"]:
                        val = random.choice(["优质材料", "标准款", "高性能版"])
                    cur.execute(
                        "INSERT IGNORE INTO sp_product_attributes (product_id, attribute_id, value, sort_order) "
                        "VALUES (%s, %s, %s, 0)",
                        (spu_id, attr_id, val),
                    )

        print(f"  SPU: {product_count}, SKU: {total_skus}")

        cat_brand_groups = {
            11: range(1, 7), 12: range(1, 12), 13: range(1, 8),
            14: range(1, 8), 15: range(1, 8),
            16: [12, 13, 14, 15, 16, 21, 30, 32],
            17: [14, 15, 16, 17, 30, 31, 32],
            18: [12, 13, 14, 15, 16],
            19: [12, 13, 17, 18, 19, 20],
            20: [12, 13, 14, 15, 16, 17, 18, 19, 20],
            21: [12, 13, 14, 15, 16, 30, 31, 32],
            22: range(22, 26), 23: range(22, 26), 24: range(22, 26),
            25: range(22, 26), 26: range(22, 26),
            28: range(26, 30), 29: range(26, 30),
            30: [26, 27, 28, 29], 31: [26, 27, 28, 29], 32: [26, 27, 28, 29],
            33: [12, 13, 17, 18, 19, 20],
            34: [12, 13, 17, 18, 19, 20],
            35: [12, 13, 17, 18, 19, 20],
        }
        cb_count = 0
        for i, (cat_parent_id, _, cat_level) in enumerate(CATEGORIES, 1):
            if cat_level == 1:
                continue
            key = i if cat_level == 2 else cat_parent_id
            group = cat_brand_groups.get(key, range(1, 33))
            brand_ids = random.sample(list(group), min(len(list(group)), random.randint(3, 8)))
            for bid in brand_ids:
                cur.execute(
                    "INSERT IGNORE INTO sp_category_brands (category_id, brand_id) VALUES (%s, %s)",
                    (cat_ids[i], bid),
                )
                cb_count += 1
        print(f"  类目-品牌: {cb_count}")

    conn.commit()
    print("商品中心 ✅\n")


# ── 库存中心 ──────────────────────────────────────

def seed_inventory(conn):
    with conn.cursor() as cur:
        # 创建默认仓库（sp_inventories FK 引用 sp_warehouses.id）
        cur.execute("SELECT id FROM sp_warehouses LIMIT 1")
        wh = cur.fetchone()
        if not wh:
            cur.execute(
                "INSERT INTO sp_warehouses (warehouse_name, warehouse_type, status) "
                "VALUES (%s, 1, 1)", ("默认仓库",),
            )
            wh_id = cur.lastrowid
        else:
            wh_id = wh[0]

        cur.execute("SELECT id FROM sp_skus WHERE deleted_at IS NULL")
        skus = cur.fetchall()
        for sku in skus:
            roll = random.random()
            if roll < 0.10:
                qty, reserved, threshold = 0, 0, random.randint(5, 30)
                status = 3  # 无货
            elif roll < 0.25:
                threshold = random.randint(10, 30)
                qty = random.randint(1, threshold - 1)
                reserved = random.randint(0, min(qty, 5))
                status = 2  # 缺货
            else:
                qty = random.randint(50, 1000)
                reserved = random.randint(0, int(qty * 0.3))
                threshold = random.randint(5, 50)
                status = 1 if qty > threshold else 2  # 充足/缺货
            cur.execute(
                "INSERT INTO sp_inventories (sku_id, warehouse_id, quantity, reserved, threshold, status) "
                "VALUES (%s, %s, %s, %s, %s, %s)",
                (sku[0], wh_id, qty, reserved, threshold, status),
            )

            if random.random() < 0.3:
                delta = random.randint(10, 50)
                cur.execute(
                    "INSERT INTO sp_inventory_logs (sku_id, warehouse_id, before_quantity, after_quantity, "
                    "before_reserved, after_reserved, change_amount, "
                    "change_type, reference_id, operator, note) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                    (sku[0], wh_id, qty - delta, qty, 0, reserved, delta,
                     "purchase", "", "admin", "初始入库"),
                )
    conn.commit()
    print(f"  库存: {len(skus)} 条")
    print("库存中心 ✅\n")


# ── 营销中心 ──────────────────────────────────────

def seed_marketing(conn):
    now = datetime.now()
    now_str = now.strftime(FMT)

    promos = [
        ("满200减30", 4, 20000, 3000, 1, 1000),
        ("满500减100", 4, 50000, 10000, 1, 500),
        ("满1000减200", 4, 100000, 20000, 1, 300),
        ("全场8折", 5, 0, 20, 0, 0),
        ("全场85折", 5, 0, 15, 0, 0),
        ("新用户满减券", 1, 0, 5000, 1, 500),
        ("新用户专属8折", 1, 0, 20, 1, 300),
        ("会员9折", 6, 0, 10, 0, 0),
        ("会员85折", 6, 0, 15, 0, 0),
        ("限时秒杀-手机", 3, 0, 50, 1, 50),
        ("限时秒杀-耳机", 3, 0, 30, 2, 100),
        ("限时秒杀-运动鞋", 3, 0, 40, 1, 80),
        ("限时秒杀-化妆品", 3, 0, 25, 2, 120),
        ("双11预售", 2, 0, 0, 1, 1000),
        ("618大促", 2, 0, 0, 1, 1000),
        ("品牌日特惠", 2, 0, 0, 1, 500),
        ("圣诞限定折扣", 2, 0, 0, 1, 300),
    ]

    with conn.cursor() as cur:
        for i, (name, ptype, condition, benefit, per_limit, total_qty) in enumerate(promos, 1):
            start = (now - timedelta(days=random.randint(0, 5))).strftime(FMT)
            end = (now + timedelta(days=random.randint(3, 30))).strftime(FMT)
            status = random.choices([1, 2, 3], weights=[1, 8, 1])[0]

            cur.execute(
                "INSERT INTO mkt_promotions (promo_name, promo_type, promo_code, start_time, end_time, "
                "total_quantity, per_user_limit, used_quantity, status, created_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (name, ptype, f"PROMO{i:04d}", start, end,
                 total_qty, per_limit, random.randint(0, int(total_qty * 0.5)), status, now_str),
            )
            promo_id = cur.lastrowid

            rule_condition = 2 if condition > 0 else 1
            cur.execute(
                "INSERT INTO mkt_promotion_rules (promotion_id, rule_name, condition_type, condition_value, "
                "benefit_type, benefit_value, created_at) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (promo_id, f"{name}规则", rule_condition, condition,
                 1 if ptype in [4, 5, 6, 7, 8] else 2, benefit, now_str),
            )

            if ptype == 3:
                cur.execute("SELECT id FROM sp_products ORDER BY RAND() LIMIT %s", (random.randint(3, 8),))
                for p in cur.fetchall():
                    cur.execute(
                        "INSERT INTO mkt_promotion_products (promotion_id, product_type, product_id, created_at) "
                        "VALUES (%s, 3, %s, %s)", (promo_id, p[0], now_str),
                    )

    conn.commit()
    print("营销中心 ✅\n")


NOTIFICATION_TEMPLATES = [
    ("system_announcement", 1, "系统公告",
     "【系统公告】{{message}}", 1, 1),
    ("maintenance_notice", 1, "系统维护通知",
     "系统将于 {{start_time}} 至 {{end_time}} 进行维护升级，期间部分功能可能暂时不可用，敬请谅解。", 1, 2),
    ("order_shipped", 1, "订单已发货",
     "您的订单 {{order_no}} 已由 {{courier_company}} 发出，运单号 {{tracking_no}}，请留意查收。", 2, 1),
    ("order_delivered", 1, "订单已签收",
     "您的订单 {{order_no}} 已签收，感谢您的购买。", 2, 1),
    ("order_cancelled", 1, "订单已取消",
     "您的订单 {{order_no}} 已被取消，{{reason}}", 2, 2),
    ("security_login_alert", 1, "登录安全提醒",
     "您的账户于 {{login_time}} 通过 {{device}} 登录。如非本人操作，请立即修改密码。", 5, 2),
    ("password_changed", 1, "密码修改通知",
     "您的账户密码已于 {{change_time}} 修改成功。如非本人操作，请立即联系客服。", 5, 1),
    ("marketing_promotion", 1, "优惠活动",
     "{{promotion_name}} 活动进行中，{{message}}", 3, 3),
]


# ── 通知模板 ───────────────────────────────────────

def seed_notification(conn):
    with conn.cursor() as cur:
        for code, channel, title, content, category, priority in NOTIFICATION_TEMPLATES:
            cur.execute(
                "INSERT IGNORE INTO base_notification_templates "
                "(template_code, channel, title_template, content_template, category, priority, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, 1)",
                (code, channel, title, content, category, priority),
            )
    conn.commit()
    print(f"  通知模板: {len(NOTIFICATION_TEMPLATES)} 条")
    print("通知模板 ✅\n")


MERCHANTS = [
    ("Apple 官方旗舰店", 3, 3, "苹果", "1000000000"),
    ("小米官方旗舰店", 2, 3, "小米", "1000000001"),
    ("华为官方旗舰店", 2, 3, "华为", "1000000002"),
    ("耐克官方旗舰店", 2, 3, "耐克", "1000000003"),
    ("欧莱雅官方旗舰店", 2, 2, "欧莱雅", "1000000004"),
    ("三星官方旗舰店", 2, 2, "三星", "1000000005"),
    ("优衣库旗舰店", 2, 2, "优衣库", "1000000006"),
    ("个人数码小店", 1, 1, "小王", "1000000007"),
]


# ── 商户中心 ──────────────────────────────────────

def seed_merchant(conn):
    now = datetime.now()
    with conn.cursor() as cur:
        # 获取现有用户（用于分配商户员工）
        cur.execute("SELECT id FROM usr_users WHERE deleted_at IS NULL")
        users = [u[0] for u in cur.fetchall()]

        for mch_name, mch_type, mch_level, contact, phone in MERCHANTS:
            code = f"MCH{random.randint(10000, 99999)}"
            cur.execute(
                "INSERT INTO mch_merchants (merchant_name, merchant_code, merchant_type, merchant_level, "
                "contact_person, contact_phone, status, audit_status, commission_rate, settlement_cycle, "
                "settled_at, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, 1, 1, %s, 1, %s, %s, %s)",
                (mch_name, code, mch_type, mch_level, contact, phone,
                 random.randint(10, 80),  # 佣金率(千分比 1.0%-8.0%)
                 now.strftime(FMT), now.strftime(FMT), now.strftime(FMT)),
            )
            merchant_id = cur.lastrowid

            # 联系人（1-2个）
            for r in range(random.randint(1, 2)):
                name = f"{random.choice(['张','李','王','赵','刘'])}{random.choice(['伟','芳','娜','强','敏'])}"
                cur.execute(
                    "INSERT INTO mch_merchant_contacts (merchant_id, contact_name, contact_phone, contact_role, is_primary) "
                    "VALUES (%s, %s, %s, %s, %s)",
                    (merchant_id, name, f"138{random.randint(10000000, 99999999)}",
                     random.choice(["finance", "operation", "legal"]),
                     1 if r == 0 else 0),
                )

            # 银行账户
            cur.execute(
                "INSERT INTO mch_merchant_bank_accounts (merchant_id, bank_name, bank_branch, account_name, account_no, "
                "account_type, is_default, status) VALUES (%s, %s, %s, %s, %s, %s, 1, 1)",
                (merchant_id,
                 random.choice(["中国工商银行", "中国建设银行", "中国银行", "招商银行"]),
                 random.choice(["上海分行", "北京分行", "深圳分行", "广州分行"]),
                 mch_name, f"{random.randint(100000000000, 999999999999)}",
                 random.choice([1, 2])),
            )

            # 资质
            for qual in ["business_license", "brand_authorization"]:
                cur.execute(
                    "INSERT INTO mch_merchant_qualifications (merchant_id, qualification_type, qualification_name, "
                    "file_url, expire_at, status) VALUES (%s, %s, %s, %s, %s, 1)",
                    (merchant_id, qual, f"{mch_name}_{qual}",
                     f"https://cdn.eshop.dev/qual/{merchant_id}/{qual}.pdf",
                     (now + timedelta(days=random.randint(180, 730))).strftime(FMT)),
                )

            # 资金余额
            cur.execute(
                "INSERT INTO mch_merchant_balances (merchant_id, available_balance, freeze_balance, version) "
                "VALUES (%s, %s, %s, 0)",
                (merchant_id, random.randint(1000000, 50000000), random.randint(0, 500000)),
            )

            # 商户员工（随机分配1-3个用户为该商户的员工）
            if users:
                assigned = random.sample(users, min(len(users), random.randint(1, 3)))
                for uid in assigned:
                    cur.execute(
                        "INSERT IGNORE INTO mch_merchant_users (merchant_id, user_id, role_id, status) "
                        "VALUES (%s, %s, 7, 1)",
                        (merchant_id, uid),
                    )

        print(f"  商户: {len(MERCHANTS)}")
    conn.commit()
    print("商户中心 ✅\n")


# ── 用户中心 ──────────────────────────────────────

def seed_users(conn):
    """插入固定用户 admin(1) 和 colin(2)，密码均为 123456（bcrypt cost=10）"""
    with conn.cursor() as cur:
        # admin
        cur.execute("""
            INSERT IGNORE INTO usr_users (id, username, password_hash, nickname, email, phone, status, register_source)
            VALUES (1, 'admin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC',
                    '管理员', 'admin@eshop.dev', '13800000001', 1, 'admin')
        """)
        if cur.lastrowid:
            cur.execute("INSERT IGNORE INTO usr_infos (user_id) VALUES (1)")
            cur.execute("INSERT IGNORE INTO usr_user_roles (user_id, role_id) "
                        "VALUES (1, (SELECT id FROM usr_roles WHERE name = 'admin'))")

        # colin
        cur.execute("""
            INSERT IGNORE INTO usr_users (id, username, password_hash, nickname, email, phone, status, register_source)
            VALUES (2, 'colin', '$2a$10$HFzEUNEVKJQCZ4aPYVb/YONrhix2jwj8iiJWM5TUZdXM4wPdkEllC',
                    'Colin', 'colin@eshop.dev', '13800000002', 1, 'web')
        """)
        if cur.lastrowid:
            cur.execute("INSERT IGNORE INTO usr_infos (user_id) VALUES (2)")
            cur.execute("INSERT IGNORE INTO usr_user_roles (user_id, role_id) "
                        "VALUES (2, (SELECT id FROM usr_roles WHERE name = 'user'))")
        # 收货地址（先删后插，因 usr_addresses 无唯一约束，INSERT IGNORE 无效）
        cur.execute("DELETE FROM usr_addresses WHERE user_id IN (1, 2)")
        cur.execute("""
            INSERT INTO usr_addresses (user_id, consignee, phone, country, province, city, district, detail, zip_code, tag, is_default)
            VALUES (1, '张管理', '13800138001', '中国', '北京市', '北京市', '朝阳区', '建国路88号SOHO现代城A座1508', '100022', 'office', TRUE)
        """)
        cur.execute("""
            INSERT INTO usr_addresses (user_id, consignee, phone, country, province, city, district, detail, zip_code, tag, is_default)
            VALUES (1, '张管理', '13800138002', '中国', '北京市', '北京市', '海淀区', '中关村大街1号银谷大厦2005', '100080', 'office', FALSE)
        """)
        cur.execute("""
            INSERT INTO usr_addresses (user_id, consignee, phone, country, province, city, district, detail, zip_code, tag, is_default)
            VALUES (2, '陈科林', '13900139001', '中国', '广东省', '深圳市', '南山区', '科技园南区高新南一道2号飞亚达科技大厦12F', '518057', 'company', TRUE)
        """)
        cur.execute("""
            INSERT INTO usr_addresses (user_id, consignee, phone, country, province, city, district, detail, zip_code, tag, is_default)
            VALUES (2, '陈科林', '13900139002', '中国', '广东省', '广州市', '天河区', '珠江新城华夏路16号富力盈凯广场3001', '510623', 'company', FALSE)
        """)
    conn.commit()
    print("  用户: admin, colin (固定)")
    print("  地址: 4 条")
    print("用户中心 ✅\n")


# ── 订单中心 ──────────────────────────────────────

PARENT_ORDER_STATUSES = ["pending", "paid", "completed", "cancelled", "refunded"]
PARENT_ORDER_STATUS_WEIGHTS = [1, 3, 4, 1, 1]
SUB_ORDER_STATUS_MAP = {
    "pending": "pending",
    "paid": "paid",
    "completed": "delivered",
    "cancelled": "cancelled",
    "refunded": "refunded",
}


def seed_order(conn):
    now = datetime.now()
    FMT = "%Y-%m-%d %H:%M:%S"

    with conn.cursor() as cur:
        cur.execute("""
            SELECT s.id, s.product_id, s.sku_code, s.price, s.spec, p.name, p.main_image
            FROM sp_skus s JOIN sp_products p ON p.id = s.product_id
            WHERE s.deleted_at IS NULL AND p.deleted_at IS NULL
        """)
        skus = cur.fetchall()
        if not skus:
            print("  ⚠ 无 SKU 数据，跳过订单生成")
            return
        sku_weights = [max(1, 100 - i * 0.4) for i in range(len(skus))]

        cur.execute("SELECT id FROM usr_users WHERE deleted_at IS NULL")
        users = cur.fetchall()
        if len(users) < 20:
            existing_ids = {u[0] for u in users}
            for i in range(1, 51):
                if i in existing_ids:
                    continue
                username = f"test_user_{i}"
                nickname = f"{random.choice(['小明','小红','张三','李四','王五','赵六','测试','游客'])}{i}"
                cur.execute(
                    "INSERT IGNORE INTO usr_users (username, password_hash, nickname, phone, email, status, register_source) "
                    "VALUES (%s, %s, %s, %s, %s, 1, 'pc')",
                    (username, f"hash_{i}", nickname, f"1{i:09d}", f"user{i}@test.com"),
                )
                if cur.lastrowid:
                    cur.execute("INSERT IGNORE INTO usr_infos (user_id) VALUES (%s)", (cur.lastrowid,))
                    existing_ids.add(cur.lastrowid)
            conn.commit()
            cur.execute("SELECT id FROM usr_users WHERE deleted_at IS NULL")
            users = cur.fetchall()

        cur.execute("SELECT id, promo_type FROM mkt_promotions")
        for promo_id, promo_type in cur.fetchall():
            if promo_type == 3:
                continue
            recipients = random.sample(users, min(len(users), max(1, int(len(users) * random.uniform(0.3, 0.8)))))
            for u in recipients:
                expire = now + timedelta(days=random.randint(7, 60))
                cur.execute(
                    "INSERT IGNORE INTO mkt_user_promotions (user_promotion_no, user_id, promotion_id, expire_time, status) "
                    "VALUES (%s, %s, %s, %s, 1)",
                    (f"UPROMO{u[0]}-{promo_id}", u[0], promo_id, expire.strftime(FMT)),
                )

        total_orders = 0
        total_items = 0
        total_payments = 0

        for _ in range(2000):
            order_date = now - timedelta(
                days=random.randint(0, 30), hours=random.randint(0, 23), minutes=random.randint(0, 59),
            )
            order_no = f"ORD{order_date.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
            user_id = random.choice(users)[0]
            parent_status = random.choices(PARENT_ORDER_STATUSES, weights=PARENT_ORDER_STATUS_WEIGHTS)[0]
            sub_status = SUB_ORDER_STATUS_MAP[parent_status]

            item_count = random.randint(1, 4)
            order_skus = random.choices(skus, weights=sku_weights, k=item_count)
            total_amount = 0
            order_items = []

            for sku in order_skus:
                sku_id, prod_id, sku_code, price, spec, prod_name, image = sku
                qty = random.randint(1, 3)
                subtotal = price * qty
                total_amount += subtotal
                order_items.append((sku_id, prod_id, sku_code, price, qty, subtotal, prod_name, image, spec))

            shipping_fee = random.choice([0, 0, 0, 800, 1200])
            discount = random.randint(0, int(total_amount * 0.1))
            pay_amount = total_amount + shipping_fee - discount
            if pay_amount <= 0:
                pay_amount = total_amount

            payment_status = "paid" if parent_status in ("paid", "completed") \
                else "unpaid" if parent_status == "pending" \
                else "refunded"

            consignee = f"用户{user_id}"
            phone = f"138{random.randint(10000000, 99999999)}"

            cur.execute(
                """INSERT INTO tx_orders (order_no, user_id, total_amount, discount_amount, shipping_fee,
                   pay_amount, status, payment_status, consignee, phone,
                   province, city, district, detail_addr, source, created_at, updated_at)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (order_no, user_id, total_amount, discount, shipping_fee,
                 pay_amount, parent_status, payment_status,
                 consignee, phone,
                 random.choice(["广东省", "浙江省", "北京市", "上海市", "四川省"]),
                 random.choice(["广州市", "杭州市", "海淀区", "浦东新区", "成都市"]),
                 random.choice(["天河区", "西湖区", "中关村", "陆家嘴", "高新区"]),
                 f"{random.randint(100,999)}号{random.choice(['小区','大厦','路'])}{random.randint(1,99)}栋",
                 random.choice(["pc", "mobile", "pc", "pc"]),
                 order_date.strftime(FMT), order_date.strftime(FMT)),
            )
            order_id = cur.lastrowid

            # 按商家拆分子订单（测试数据所有 SKU 都归为商家 0，但保留拆分结构）
            sub_order_no = f"SO{order_date.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
            sub_total = total_amount
            sub_shipping = shipping_fee
            sub_discount = discount
            sub_pay = pay_amount

            time_fields = {}
            if parent_status in ("paid", "completed"):
                time_fields["paid_at"] = (order_date + timedelta(minutes=random.randint(1, 60))).strftime(FMT)
            if sub_status in ("shipped", "delivered"):
                time_fields["shipped_at"] = (order_date + timedelta(hours=random.randint(2, 48))).strftime(FMT)
            if sub_status == "delivered":
                time_fields["delivered_at"] = (order_date + timedelta(hours=random.randint(48, 120))).strftime(FMT)
            if parent_status == "completed":
                time_fields["completed_at"] = (order_date + timedelta(days=random.randint(3, 7))).strftime(FMT)
            if parent_status == "cancelled":
                time_fields["closed_at"] = (order_date + timedelta(hours=random.randint(1, 24))).strftime(FMT)

            cur.execute(
                """INSERT INTO tx_sub_orders (sub_order_no, parent_order_id, parent_order_no, user_id,
                   total_amount, discount_amount, shipping_fee, pay_amount, status,
                   paid_at, shipped_at, delivered_at, completed_at, closed_at,
                   created_at, updated_at)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s,
                   %s, %s, %s, %s, %s, %s, %s)""",
                (sub_order_no, order_id, order_no, user_id,
                 sub_total, sub_discount, sub_shipping, sub_pay, sub_status,
                 time_fields.get("paid_at"), time_fields.get("shipped_at"),
                 time_fields.get("delivered_at"), time_fields.get("completed_at"),
                 time_fields.get("closed_at"),
                 order_date.strftime(FMT), order_date.strftime(FMT)),
            )
            sub_order_id = cur.lastrowid

            for item in order_items:
                sku_id, prod_id, sku_code, price, qty, subtotal, prod_name, image, spec = item
                cur.execute(
                    """INSERT INTO tx_order_items (order_id, sub_order_id, order_no, sub_order_no,
                       sku_id, product_id, sku_code, product_name, sku_spec, image,
                       price, quantity, subtotal, created_at, updated_at)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                    (order_id, sub_order_id, order_no, sub_order_no,
                     sku_id, prod_id, sku_code, prod_name,
                     spec if spec and spec != "{}" else None, image,
                     price, qty, subtotal,
                     order_date.strftime(FMT), order_date.strftime(FMT)),
                )
                total_items += 1

                if parent_status not in ("cancelled", "pending"):
                    cur.execute(
                        "SELECT quantity, reserved FROM sp_inventories WHERE sku_id = %s FOR UPDATE",
                        (sku_id,),
                    )
                    inv = cur.fetchone()
                    if inv:
                        before_qty, before_reserved = int(inv[0]), int(inv[1])
                        after_qty = max(0, before_qty - qty)
                        after_reserved = max(0, before_reserved - qty)
                        cur.execute(
                            "UPDATE sp_inventories SET quantity = %s, reserved = %s, status = %s WHERE sku_id = %s",
                            (after_qty, after_reserved,
                             3 if after_qty <= 0 else 2 if after_qty < 10 else 1, sku_id),
                        )
                        cur.execute(
                            """INSERT INTO sp_inventory_logs (sku_id, change_type, before_quantity, after_quantity,
                               before_reserved, after_reserved, change_amount, reference_id, operator, note)
                               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                            (sku_id, "order", before_qty, after_qty,
                             before_reserved, after_reserved, -qty, order_no, "system", "订单扣减"),
                        )

            if parent_status in ("paid", "completed", "refunded"):
                paid_at = order_date + timedelta(minutes=random.randint(1, 60))
                payment_no = f"PAY{paid_at.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
                payment_method = random.choice(["alipay", "wechat", "alipay", "wechat", "wallet"])
                cur.execute(
                    """INSERT INTO tx_payments (payment_no, order_no, order_id, amount, payment_method,
                       channel, trade_type, status, paid_at, created_at, updated_at)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                    (payment_no, order_no, order_id, pay_amount, payment_method,
                     payment_method, "native",
                     "success" if parent_status != "refunded" else "refunded",
                     paid_at.strftime(FMT), order_date.strftime(FMT), paid_at.strftime(FMT)),
                )
                payment_id = cur.lastrowid
                total_payments += 1

                if parent_status == "refunded":
                    refund_no = f"RFD{paid_at.strftime('%Y%m%d%H%M%S')}{random.randint(1000,9999)}"
                    cur.execute(
                        """INSERT INTO tx_refunds (refund_no, payment_id, payment_no, order_no, order_id,
                           amount, reason, status, applied_at, success_at, created_at, updated_at)
                           VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                        (refund_no, payment_id, payment_no, order_no, order_id,
                         pay_amount, "测试退款", "success",
                         (order_date + timedelta(days=1)).strftime(FMT),
                         paid_at.strftime(FMT), order_date.strftime(FMT), paid_at.strftime(FMT)),
                    )

            total_orders += 1

    conn.commit()
    print(f"  订单: {total_orders}, 订单项: {total_items}, 支付: {total_payments}")
    print("订单中心 ✅\n")


def main():
    parser = argparse.ArgumentParser(description="为新表生成测试数据")
    parser.add_argument("--clean", action="store_true", help="先清空再生成")
    parser.add_argument("--module", choices=["product", "inventory", "marketing", "merchant", "users", "order", "notification"],
                        help="只生成指定模块")
    args = parser.parse_args()

    conn = connect()
    if args.clean:
        clean(conn)

    modules = {
        "product": seed_product,
        "inventory": seed_inventory,
        "marketing": seed_marketing,
        "merchant": seed_merchant,
        "users": seed_users,
        "order": seed_order,
        "notification": seed_notification,
    }

    if args.module:
        if args.module in modules:
            modules[args.module](conn)
        else:
            print(f"未知模块: {args.module}")
    else:
        for name, fn in modules.items():
            print(f"正在生成: {name}")
            fn(conn)

    with conn.cursor() as cur:
        for table in ["sp_brands", "sp_categories", "sp_attributes", "sp_products",
                      "sp_skus", "sp_product_descriptions", "sp_product_attributes",
                      "sp_inventories", "mkt_promotions", "mkt_user_promotions",
                      "tx_orders", "tx_sub_orders", "tx_order_items", "tx_payments", "tx_refunds",
                      "tx_deliveries", "usr_addresses", "usr_levels", "usr_points",
                      "mch_merchants", "mch_merchant_balances",
                      "base_notification_templates"]:
            cur.execute(f"SELECT COUNT(*) AS cnt FROM {table}")
            row = cur.fetchone()
            print(f"  {table}: {row[0]}")

    conn.close()
    print("\n完成!")


if __name__ == "__main__":
    main()
