# 1. Install the framework via pip
pip install pre-commit

# 2. Generate a default configuration file
pre-commit sample-config > .pre-commit-config.yaml

# 3. Bind the framework to your Git repository hooks
pre-commit install
