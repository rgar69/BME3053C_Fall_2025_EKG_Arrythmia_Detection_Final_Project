**COVID CRACKDOWN: Isolationism** is a Streamlit-based management sim focused on balancing patient triage, infection control, and supply logistics during an isolation-ward COVID surge. It replaces the previous Love2D prototype with a zero-install, browser-delivered control dashboard.

## Biomedical Context

Players assume the role of an on-duty hospital isolation administrator. Each hour involves triaging incoming patients, assigning them to the appropriate ward, initiating treatments, and tightly managing PPE, ventilators, and medications—all while preventing hospital-acquired infections and staff outbreaks.

## Quick Start Instructions

### Opening in GitHub Codespaces
1. Click **Code → Create codespace on main** on the repository homepage.
2. Wait for the container to build, then open the integrated terminal.
3. If `pip` or `streamlit` is missing in this Alpine-based container, use these commands:
	```bash
	sudo apk add --no-cache python3 py3-pip   # install python and pip in the container
	python3 -m venv .venv                     # create a project venv
	source .venv/bin/activate                 # activate it in the current shell
	pip install --upgrade pip
	pip install -r requirements.txt           # pulls in streamlit and friends
	streamlit run app.py                      # launches the app
	```
	- In a new terminal, run `source .venv/bin/activate` before `streamlit run app.py`.
	- Codespaces will expose port 8501; open it from the Ports panel.

### Local Setup
1. Ensure Python 3.10+ is installed.
2. (Optional) Create and activate a virtual environment: `python -m venv .venv && source .venv/bin/activate`.
3. Install dependencies: `pip install -r requirements.txt`.

### Running the Application
```bash
streamlit run app.py
```
Streamlit outputs a local URL (or a forwarded URL in Codespaces). Open the link in a browser tab to interact with the dashboard.

## Usage Guide

- **Advance Time:** Sidebar controls (+1h, +6h, +24h) progress the simulation. New patients, treatments, and events process each simulated hour.
- **Patients Tab:** Displays vitals, test status, and ward assignments. COVID-specific tests or broader infection panels determine whether isolation beds can be used.
- **Treatments Tab:** Surfaces patient vitals and toggles therapies (oxygen, antivirals, steroids, ventilators). Each treatment consumes supplies and alters recovery odds.
- **Diagnostics Reference Tab:** Provides symptom clusters, vital thresholds, and quarantine rules for common pathogens (COVID, influenza, strep, adenovirus) without leaving the game.
- **Supplies Tab:** Tracks PPE/tests/meds/vaccines, handles resupply orders, and launches vaccination drives to suppress infection risk.
- **Policies & Upgrades Tab:** Allocates funds toward mask mandates, visitor lockdowns, ward expansions, ventilators, and rapid testing upgrades.
- **Dashboard Tab:** Monitors KPIs, cumulative outcomes, and the live event log. End conditions (too many deaths, staff losses, or bed saturation) appear here.

## Data Description

All patient vitals, symptoms, and outcomes are procedurally generated via the `game_modules` package. No real patient data is used. Random seeds are derived from system time but can be injected for reproducible runs.

## Project Structure

- `app.py` – Streamlit UI, tabs, metrics, and command handlers.
- `game_modules/` – Game package entry that exposes the simulation API.
	- `modules/` – Supporting systems that power the simulation:
		- `patients.py` – Patient factory, vitals progression, risk logic.
		- `infections.py` – Infection catalog, weighted pathogen selection, and reference data for the UI.
		- `treatments.py` – Treatment catalog and resource effects.
		- `supplies.py` – Supply inventories, purchase orders, logistics delays.
		- `hospital.py` – Core game loop, infection model, policies, scoring.
		- `__init__.py` – Marks the modules directory as a package.
- `docs/architecture.md` – Detailed module and system design notes.
- `requirements.txt` – Minimal runtime dependencies for Streamlit and pandas.

## Tech Stack

- **Frontend:** Streamlit (interactive dashboard UI)
- **Simulation:** Dataclasses, pandas for tabular display, custom stochastic models
- **Runtime:** Python 3.10+

## Contributing

1. Fork the repo and create a feature branch.
2. Install deps with `pip install -r requirements.txt`.
3. Run `streamlit run app.py` and verify changes.
4. Submit a PR describing gameplay and UI updates.

