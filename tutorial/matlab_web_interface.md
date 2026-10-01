## Using Matlab - installed on a remote linux server - in a browser
Using matlab in an x2goclient is a dreadful experience. However it is possible to run it in a web browser using the [jupyter matlab proxy](https://github.com/mathworks/jupyter-matlab-proxy). The setup is a bit complex, but it needs to be done only once. Here are the steps:

### First time
1. Prepare a new python (3.10+) virtual environment, activate it and install these libraries:
```bash
# Create the virtual environment
python3 -m venv venv_matlab

# Activate it
source venv_matlab/bin/activate

# Install the libraries
pip install jupyterlab jupyter-matlab-proxy notebook
```

2. Launch jupyter lab on the port 5100
```
jupyter lab --no-browser --port=5100
```

A large amount of text will be printed in the terminal. The line to pay attention to is towards the end, starting with `localhost`. Copy that address.

NB: if the port is occupied, it will launch on the closest (likely next) available port. Note down the number for the next step


3. Open the port, e.g. using VS code terminal

4. Open matlab in the browser
Open Chrome or another (decent) browser, and paste the localhost address. Jupyter lab will open, and on top you will see an icon allowing you to launch the matlab web interface in a new tab.

### Subsequent times
- Activate the python environment
- Launch jupyter lab 
- Open the port in VS code
- Paste the localhost link in the browser and open matlab in a new tab







