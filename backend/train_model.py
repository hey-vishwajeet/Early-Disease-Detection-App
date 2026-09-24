"""One training command for the student prototype: python backend/train_model.py."""
from research.data import DATA_DIR
from research.training import train

if __name__ == '__main__':
    if not (DATA_DIR / 'heart.csv').exists():
        from fetch_heart import main as fetch
        fetch()
    bundle = train()
    print('Selected inputs:', ', '.join(f['name'] for f in bundle['metadata']['features']))
    print('Saved both fitted pipelines. Start the API with: python backend/app.py')
