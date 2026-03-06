from dataclasses import dataclass


@dataclass
class WorkerDispatcher:
    queue_name: str = "purview-jobs"

    def describe(self) -> str:
        return "Phase 0 worker scaffold (no real queue processing)."
