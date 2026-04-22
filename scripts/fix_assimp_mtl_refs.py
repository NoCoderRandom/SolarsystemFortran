import argparse
import os
import re


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mtl", required=True)
    parser.add_argument("--texture-dir", required=True)
    parser.add_argument("--prefix", required=True)
    args = parser.parse_args()

    with open(args.mtl, "r", encoding="utf-8") as f:
        lines = f.readlines()

    out = []
    for line in lines:
        match = re.match(r"^(map_Kd|map_bump|bump)\s+\*(\d+)\s*$", line.strip())
        if match:
            kind = match.group(1)
            idx = match.group(2)
            candidates = []
            for ext in (".png", ".jpg", ".jpeg", ".tga", ".bmp"):
                candidates.append(f"{args.prefix}_img{idx}{ext}")
            resolved = None
            for cand in candidates:
                path = os.path.join(args.texture_dir, cand)
                if os.path.isfile(path):
                    resolved = os.path.join("textures", cand)
                    break
            if resolved is not None:
                out.append(f"{kind} {resolved}\n")
                continue
        out.append(line)

    with open(args.mtl, "w", encoding="utf-8") as f:
        f.writelines(out)


if __name__ == "__main__":
    main()
