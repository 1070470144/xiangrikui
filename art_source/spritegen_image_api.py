"""Run SpriteGen with the explicitly configured compatible image endpoint."""
import os

from sprite_gen.gen import openai_provider
from sprite_gen.cli import main

if os.environ.get("OPENAI_BASE_URL"):
    openai_provider.API_BASE = os.environ["OPENAI_BASE_URL"].rstrip("/")

if __name__ == "__main__":
    main()
