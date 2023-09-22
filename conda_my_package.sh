# You can try sourcing the following, but maybe safer to run them line-by-line by copy and paste
conda create --prefix conda_my_package python=3.10
conda activate ./conda_my_package

pip install -r requirements.txt
pip install -r requirements.devel.txt
pip install -e .
