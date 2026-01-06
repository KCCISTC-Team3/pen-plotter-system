conda env remove -n python_env -y
conda env create -f environment.yml
conda activate python_env
python -m pip install --upgrade pip