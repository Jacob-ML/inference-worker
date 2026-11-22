"""
Runpod handler for processing jobs using LlamaCPP or OpenAI engines. This
module defines an asynchronous handler function that receives job inputs,
instantiates the appropriate engine based on the job input, and yields
generated output in a streaming fashion.
"""

from typing import Any
import runpod
import os
from utils import JobInput
from engine import LlamaCPPEngine, LlamaCPPOpenAIEngine

DEFAULT_MAX_CONCURRENCY = 1
max_concurrency = int(os.getenv("MAX_CONCURRENCY", DEFAULT_MAX_CONCURRENCY))


async def handler(job: Any):
    """
    Asynchronous handler function for processing jobs. It receives a job
    dictionary, extracts the input, determines the appropriate engine to use
    (LlamaCPP or OpenAI), and yields generated output in a streaming manner.
    """

    job_input = JobInput(job["input"])
    engine_class = (
        LlamaCPPOpenAIEngine if job_input.openai_route else LlamaCPPEngine
    )
    engine = engine_class()

    job = engine.generate(job_input)

    async for batch in job:
        yield batch

# Original code from vllm runpod_wrapper.py
#async def handler(job):
#    job_input = JobInput(job["input"])
#    engine = OpenAIvLLMEngine if job_input.openai_route else vllm_engine
#    results_generator = engine.generate(job_input)
#    async for batch in results_generator:
#        yield batch

runpod.serverless.start(
    {
        "handler": handler,
        "concurrency_modifier": lambda _x: max_concurrency,
        "return_aggregate_stream": True,
    }
)
