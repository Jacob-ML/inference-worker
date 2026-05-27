"""Find the full GGUF path from the RunPod Hugging Face model cache."""

import argparse
import os
import sys
from pathlib import Path


CACHE_DIR = Path("/runpod-volume/huggingface-cache/hub")


def candidate_cache_dirs(model_name: str) -> list[Path]:
    """
    Hugging Face cache dirs normally look like:
    /runpod-volume/huggingface-cache/hub/models--org--repo

    The original worker lowercased this, which can break repos with uppercase
    characters like *-GGUF. We try exact first, then lowercase, then scan.
    """
    exact_name = model_name.replace("/", "--")
    lower_name = exact_name.lower()

    candidates = [
        CACHE_DIR / f"models--{exact_name}",
        CACHE_DIR / f"models--{lower_name}",
    ]

    if CACHE_DIR.exists():
        wanted_lower = f"models--{exact_name}".lower()
        for child in CACHE_DIR.iterdir():
            if child.is_dir() and child.name.lower() == wanted_lower:
                if child not in candidates:
                    candidates.append(child)

    return candidates


def find_model_path(model_name: str, gguf_in_repo: str) -> Path | None:
    for model_cache_dir in candidate_cache_dirs(model_name):
        snapshots_dir = model_cache_dir / "snapshots"

        if not snapshots_dir.exists():
            continue

        snapshots = [
            p for p in snapshots_dir.iterdir()
            if p.is_dir()
        ]

        # Prefer newest snapshot if there are multiple.
        snapshots.sort(key=lambda p: p.stat().st_mtime, reverse=True)

        for snapshot in snapshots:
            model_path = snapshot / gguf_in_repo
            if model_path.exists() and model_path.is_file():
                return model_path

    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Find the full GGUF path from the Hugging Face cache."
    )
    parser.add_argument("model", type=str, help="Hugging Face model ID")
    parser.add_argument(
        "path",
        type=str,
        help="Path to the GGUF file inside the model repository",
    )

    args = parser.parse_args()
    model_path = find_model_path(args.model, args.path)

    if model_path is None:
        print(
            f"ERROR: Could not find cached GGUF.\n"
            f"  CACHE_DIR={CACHE_DIR}\n"
            f"  model={args.model}\n"
            f"  gguf_path={args.path}\n"
            f"  tried={[str(p) for p in candidate_cache_dirs(args.model)]}",
            file=sys.stderr,
        )
        return 1

    print(str(model_path), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())