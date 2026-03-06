from jobs.dispatcher import WorkerDispatcher


def main() -> None:
    dispatcher = WorkerDispatcher()
    print(dispatcher.describe())


if __name__ == "__main__":
    main()
