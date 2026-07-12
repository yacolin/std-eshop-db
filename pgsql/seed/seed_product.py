#!/usr/bin/env python3
"""
种子：商品中心 — 品牌 / 类目 / 属性 / SPU / SKU / 描述 / 扩展属性 / 类目-品牌
"""
from seed_common import *
import seed_data
from collections import OrderedDict, defaultdict
import re


def _map_input_type(name, input_type):
    if input_type == 4:
        return 4
    if input_type == 2:
        return 2
    return 1


def _parse_numeric_value(v):
    m = re.search(r'(\d+(?:\.\d+)?)', v)
    return m.group(1) if m else None


_COLOR_HEX_MAP = {
    "黑色": "#000000", "白色": "#FFFFFF", "银色": "#C0C0C0",
    "金色": "#FFD700", "红色": "#FF0000", "蓝色": "#0000FF",
    "紫色": "#800080", "绿色": "#008000", "粉色": "#FFC0CB",
    "灰色": "#808080", "卡其": "#C3B091", "荧光黄": "#FFFF00",
    "深空灰": "#43464B", "木纹": "#8B5A2B", "暖黄": "#FFD700",
    "肤色": "#FFE0BD", "玫瑰金": "#E8B4B8", "多色": "#000000",
    "条纹": "#000000", "彩色": "#FF00FF", "RGB彩光": "#FF00FF",
}


def _insert_get_id(cur, sql, params):
    cur.execute(sql + " RETURNING id", params)
    row = cur.fetchone()
    return row[0] if row else None


def seed_product(conn):
    if seed_data._GENERATED_PRODUCTS is None:
        seed_data._GENERATED_PRODUCTS = seed_data.generate_products()
        print(f"  自动生成 SPU: {len(seed_data._GENERATED_PRODUCTS)} 个")
    products = seed_data._GENERATED_PRODUCTS

    with conn.cursor() as cur:
        cur.execute("SELECT id FROM mch_merchants WHERE deleted_at IS NULL ORDER BY id")
        merchant_ids = [row[0] for row in cur.fetchall()]
        if not merchant_ids:
            print("  ⚠ 无商家数据，商品将绑定 merchant_id=0")
            merchant_ids = [0]

        brand_id_map = {}
        for name, cname, letter in BRANDS:
            bid = _insert_get_id(cur, """
                INSERT INTO sp_brands (name, english_name, first_letter, sort_order, status)
                VALUES (%s, %s, %s, %s, 1)
            """, (cname, name, letter, random.randint(1, 100)))
            brand_id_map[(cname, name)] = bid
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
            cid = _insert_get_id(cur, """
                INSERT INTO sp_categories (name, parent_id, level, path, sort_order, status)
                VALUES (%s, %s, %s, %s, %s, 1)
            """, (name, parent_id if parent_id == 0 else cat_ids.get(parent_id, 0), level, path, i * 10))
            cat_ids[i] = cid
        print(f"  类目: {len(CATEGORIES)}")

        attr_groups = OrderedDict()
        cat_attr_keys = defaultdict(set)
        for cat_idx, name, input_type, values, is_sku, searchable in ATTRS:
            key = (name, input_type)
            if key not in attr_groups:
                attr_groups[key] = {
                    "first_cat_idx": cat_idx,
                    "name": name,
                    "input_type": input_type,
                    "is_sku": is_sku,
                    "searchable": searchable,
                    "values_set": set(),
                }
            if values:
                attr_groups[key]["values_set"].update(json.loads(values))
            cat_attr_keys[cat_idx].add(key)

        alias_map = {
            "黑色": json.dumps(["纯黑", "墨色"]),
            "白色": json.dumps(["纯白", "乳白"]),
            "银色": json.dumps(["银灰", "亮银"]),
            "金色": json.dumps(["香槟金", "亮金"]),
            "红色": json.dumps(["正红", "朱红"]),
            "蓝色": json.dumps(["深蓝", "宝蓝"]),
            "紫色": json.dumps(["紫罗兰", "薰衣草"]),
            "绿色": json.dumps(["翠绿", "草绿"]),
            "粉色": json.dumps(["粉红", "樱花粉"]),
            "灰色": json.dumps(["烟灰", "中灰"]),
            "卡其": json.dumps(["卡其色", "米色"]),
            "深空灰": json.dumps(["黑灰", "石墨灰"]),
            "S": json.dumps(["小号"]),
            "M": json.dumps(["中号"]),
            "L": json.dumps(["大号"]),
            "XL": json.dumps(["加大"]),
            "XXL": json.dumps(["加加大"]),
            "XXXL": json.dumps(["加加加大"]),
            "36": json.dumps(["36码"]),
            "37": json.dumps(["37码"]),
            "38": json.dumps(["38码"]),
            "39": json.dumps(["39码"]),
            "40": json.dumps(["40码"]),
            "41": json.dumps(["41码"]),
            "42": json.dumps(["42码"]),
            "43": json.dumps(["43码"]),
            "44": json.dumps(["44码"]),
            "45": json.dumps(["45码"]),
        }

        attr_map = {}
        spec_attr_map = {}
        attr_values_map = {}

        for sort_order, (key, group) in enumerate(attr_groups.items()):
            name, input_type = key
            merged_values = json.dumps(sorted(group["values_set"])) if group["values_set"] else None
            attr_id = _insert_get_id(cur, """
                INSERT INTO sp_attributes (name, category_id, input_type, values, is_sku_spec, searchable, sort_order, status)
                VALUES (%s, %s, %s, %s::jsonb, %s, %s, %s, 1)
            """, (name, cat_ids[group["first_cat_idx"]], input_type, merged_values,
                  group["is_sku"], group["searchable"], sort_order))
            attr_map[key] = attr_id

            if merged_values:
                for vo, v in enumerate(json.loads(merged_values)):
                    alias_data = alias_map.get(v)
                    search_weight = max(100 - vo * 10, 10)
                    numeric_value = _parse_numeric_value(v) if input_type == 4 else None
                    color_hex = _COLOR_HEX_MAP.get(v, "") if input_type == 2 else ""
                    av_id = _insert_get_id(cur, """
                        INSERT INTO sp_attribute_values
                        (attribute_id, "value", alias, search_weight, numeric_value, color_hex, sort_order, status)
                        VALUES (%s, %s, %s::jsonb, %s, %s, %s, %s, 1)
                    """, (attr_id, v, alias_data, search_weight, numeric_value, color_hex, vo))
                    attr_values_map.setdefault(attr_id, []).append((av_id, v))

        for cat_idx, name, input_type, _, _, _ in ATTRS:
            key = (name, input_type)
            if key in attr_map:
                spec_attr_map[(cat_idx, name)] = attr_map[key]

        attr_count = len(attr_groups)
        print(f"  属性: {attr_count}（去重后，原{len(ATTRS)}条）")

        ca_count = 0
        seen_ca = set()
        for cat_idx, keys in cat_attr_keys.items():
            cat_id = cat_ids[cat_idx]
            for sort_order, key in enumerate(sorted(keys)):
                attr_id = attr_map.get(key)
                if attr_id is None or (cat_id, attr_id) in seen_ca:
                    continue
                seen_ca.add((cat_id, attr_id))
                cur.execute(
                    "INSERT INTO sp_category_attributes (category_id, attribute_id, sort_order) "
                    "VALUES (%s, %s, %s) ON CONFLICT DO NOTHING",
                    (cat_id, attr_id, sort_order),
                )
                ca_count += 1
        print(f"  类目-属性关联: {ca_count}")

        total_skus = 0
        product_count = 0
        for name, subtitle, cat_idx, brand_idx, price, market, unit in products:
            brand_id = brand_idx
            merchant_id = random.choice(merchant_ids)
            spu_id = _insert_get_id(cur, """
                INSERT INTO sp_products (merchant_id, name, subtitle, category_id, brand_id, unit, main_image, status)
                VALUES (%s, %s, %s, %s, %s, %s, '', 2)
            """, (merchant_id, name, subtitle, cat_ids[cat_idx], brand_id, unit))
            product_count += 1

            sku_count = random.randint(2, 6)
            generated_specs = set()
            for j in range(sku_count):
                spec_json, spec_dict = generate_spec(cat_idx)
                if spec_json in generated_specs:
                    spec_d = json.loads(spec_json)
                    color = random.choice(COLORS[:8])
                    if "颜色" in spec_d:
                        spec_d["颜色"] = color
                    spec_json = json.dumps(spec_d, ensure_ascii=False)
                    if spec_json in generated_specs:
                        continue
                generated_specs.add(spec_json)

                sku_price = price + random.randint(-int(price * 0.2), int(price * 0.3))
                sku_price = max(price - int(price * 0.3), sku_price)
                sku_code = f"SKU{spu_id}-{j+1:03d}"
                barcode = f"{random.randint(1000000000000, 9999999999999)}"
                sku_id = _insert_get_id(cur, """
                    INSERT INTO sp_skus (product_id, merchant_id, sku_code, barcode, spec, price, market_price, cost_price, status)
                    VALUES (%s, %s, %s, %s, %s::jsonb, %s, %s, %s, 1)
                """, (spu_id, merchant_id, sku_code, barcode, spec_json, sku_price,
                      sku_price + random.randint(int(sku_price * 0.1), int(sku_price * 0.3)),
                      int(sku_price * 0.6)))

                sort_order = 0
                spec_entries = json.loads(spec_json)
                for spec_name, spec_value in spec_entries.items():
                    spec_attr_id = spec_attr_map.get((cat_idx, spec_name))
                    if spec_attr_id is None:
                        continue
                    cur.execute(
                        'SELECT id FROM sp_attribute_values WHERE attribute_id = %s AND "value" = %s',
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

            for key, attr_id in attr_map.items():
                attr_name, input_type = key
                if key not in cat_attr_keys.get(cat_idx, set()):
                    continue
                valid_entries = attr_values_map.get(attr_id, [])
                if valid_entries:
                    av_id, val = random.choice(valid_entries)
                    cur.execute(
                        "INSERT INTO sp_product_attributes "
                        "(product_id, attribute_id, attribute_value_id, value, sort_order) "
                        "VALUES (%s, %s, %s, %s, 0) ON CONFLICT DO NOTHING",
                        (spu_id, attr_id, av_id, val),
                    )
                else:
                    cur.execute(
                        "INSERT INTO sp_product_attributes "
                        "(product_id, attribute_id, value, sort_order) "
                        "VALUES (%s, %s, %s, 0) ON CONFLICT DO NOTHING",
                        (spu_id, attr_id, attr_name),
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
                    "INSERT INTO sp_category_brands (category_id, brand_id) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                    (cat_ids[i], bid),
                )
                cb_count += 1
        print(f"  类目-品牌: {cb_count}")

    conn.commit()
    print("商品中心 ✅\n")
