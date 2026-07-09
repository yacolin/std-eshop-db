#!/usr/bin/env python3
"""
种子：商品中心 — 品牌 / 类目 / 属性 / SPU / SKU / 描述 / 扩展属性 / 类目-品牌
"""
from seed_common import *
import seed_data


def seed_product(conn):
    if seed_data._GENERATED_PRODUCTS is None:
        seed_data._GENERATED_PRODUCTS = seed_data.generate_products()
        print(f"  自动生成 SPU: {len(seed_data._GENERATED_PRODUCTS)} 个")
    products = seed_data._GENERATED_PRODUCTS

    with conn.cursor() as cur:
        # 获取已 seeded 的商家 ID
        cur.execute("SELECT id FROM mch_merchants WHERE deleted_at IS NULL ORDER BY id")
        merchant_ids = [row[0] for row in cur.fetchall()]
        if not merchant_ids:
            print("  ⚠ 无商家数据，商品将绑定 merchant_id=0")
            merchant_ids = [0]
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
            filterable = 1 if values else 0
            cur.execute(
                "INSERT INTO sp_attributes (name, category_id, value_type, filterable, is_sku_spec, searchable, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, 1)",
                (name, cat_ids[cat_idx], input_type, filterable, is_sku, searchable),
            )
            attr_id = cur.lastrowid
            attr_map[(cat_idx, name)] = attr_id
            if values:
                for sort_order, v in enumerate(json.loads(values)):
                    cur.execute(
                        "INSERT INTO sp_attribute_values (attribute_id, `value`, sort_order, status) "
                        "VALUES (%s, %s, %s, 1)",
                        (attr_id, v, sort_order),
                    )
        print(f"  属性: {len(ATTRS)}")

        total_skus = 0
        product_count = 0
        for name, subtitle, cat_idx, brand_idx, price, market, unit in products:
            brand_id = brand_idx
            merchant_id = random.choice(merchant_ids)
            cur.execute(
                "INSERT INTO sp_products (merchant_id, name, subtitle, category_id, brand_id, unit, main_image, status) "
                "VALUES (%s, %s, %s, %s, %s, %s, '', 2)",
                (merchant_id, name, subtitle, cat_ids[cat_idx], brand_id, unit),
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
                spec_dict = json.loads(spec_json)
                spec_summary = " / ".join(str(v) for v in spec_dict.values())
                cur.execute(
                    "INSERT INTO sp_skus (product_id, merchant_id, sku_code, barcode, spec_summary, price, market_price, cost_price, status) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 1)",
                    (spu_id, merchant_id, sku_code, barcode, spec_summary, sku_price,
                     sku_price + random.randint(int(sku_price * 0.1), int(sku_price * 0.3)),
                     int(sku_price * 0.6)),
                )
                sku_id = cur.lastrowid
                # 写入 sp_sku_specs（EAV 规格映射）
                sort_order = 0
                for spec_name, spec_value in spec_dict.items():
                    spec_attr_id = attr_map.get((cat_idx, spec_name))
                    if spec_attr_id is None:
                        continue
                    cur.execute(
                        "SELECT id FROM sp_attribute_values WHERE attribute_id = %s AND `value` = %s",
                        (spec_attr_id, spec_value),
                    )
                    row = cur.fetchone()
                    if row:
                        cur.execute(
                            "INSERT INTO sp_sku_specs (sku_id, attribute_id, attribute_value_id, sort_order) "
                            "VALUES (%s, %s, %s, %s)",
                            (sku_id, spec_attr_id, row[0], sort_order),
                        )
                        sort_order += 1
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
            group = cat_brand_groups.get(key, range(1, len(BRANDS) + 1))
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
