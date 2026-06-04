import os.path
import shutil
import subprocess
import argparse
import sys

GENERATED_FILES = {
    "bars_and_tone_file": 'bars.mp4',
}


def create_sample_files(samples_dir):
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        raise FileNotFoundError("ffmpeg not found, cannot create sample files")

    subprocess.check_call([ffmpeg, '-version'])
    subprocess.check_call(
        [ffmpeg, '-f', 'lavfi', '-i', 'smptebars=duration=5:size=640x360:rate=30', '-y', os.path.join(samples_dir, GENERATED_FILES['bars_and_tone_file'])])
    return categorize_sample_files(samples_dir)


def categorize_sample_files(sample_files_path:str):
    sample_files = {}
    for key, value in GENERATED_FILES.items():
        full_path = os.path.join(sample_files_path, value)
        if not os.path.exists(os.path.exists(full_path)):
            raise FileNotFoundError(f"Expected sample file {full_path} not found")
        sample_files[key] = full_path
    return sample_files


def get_sample_files(samples_dir):
    return categorize_sample_files(samples_dir)

def main():
    parser = argparse.ArgumentParser(description="Manage sample media files for testing")
    subparsers = parser.add_subparsers(title="subcommands", required=True, dest="subcommand", help='subcommand help')

    parser_create = subparsers.add_parser('create', help='create sample media files')
    parser_create.add_argument('output', help='output directory')
    args = parser.parse_args()
    match args.subcommand:
        case "create":
            print("creating sample media files")
            if not os.path.exists(args.output):
                print(f"Output directory {args.output} does not exist, creating it", flush=True)
                os.makedirs(args.output)
            create_sample_files(args.output)
            return 0

        case _:
            # This should never happen because argparse should enforce valid subcommands, but we include it for
            # completeness.
            print(f"Unknown subcommand: {args.subcommand}")
            return 1


if __name__ == '__main__':
    sys.exit(main())