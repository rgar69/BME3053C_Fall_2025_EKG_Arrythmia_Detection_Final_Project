from __future__ import annotations

import pandas as pd
import streamlit as st

from game_modules import Hospital, TREATMENTS, get_reference_rows

st.set_page_config(page_title="COVID CRACKDOWN: Isolationism", layout="wide", page_icon="🩺")

st.markdown(
    """
    <style>
    .metric-card {
        border: 1px solid #5a6b7d;
        border-radius: 10px;
        padding: 0.6rem 0.8rem;
        margin-bottom: 0.5rem;
        background: #0d1421;
        box-shadow: 0 0 10px rgba(6, 9, 14, 0.5);
    }
    .metric-label {
        font-size: 0.78rem;
        color: #9fb3c8;
        letter-spacing: 0.05em;
        text-transform: uppercase;
    }
    .metric-value {
        font-size: 1.35rem;
        color: #f4f8ff;
        font-weight: 600;
    }
    .metric-footer {
        font-size: 0.75rem;
        color: #7d94ad;
        margin-top: 0.15rem;
    }
    .action-button {
        margin-bottom: 0.6rem;
    }
    .action-button button {
        width: 100%;
        border: 1px solid #3d4a5d;
        border-radius: 12px;
        text-align: left;
        background: #0b1220;
        color: #f5f8ff;
        font-size: 0.95rem;
        padding: 0.75rem 0.9rem;
        line-height: 1.4;
        box-shadow: 0 0 8px rgba(5, 9, 15, 0.45);
        transition: background 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
    }
    .action-button button:hover {
        background: #111a2b;
    }
    .action-button button:focus-visible {
        outline: 2px solid #30c572;
    }
    .action-button button:disabled {
        cursor: default;
        opacity: 1;
    }
    .action-button.active button {
        border-color: #30c572;
        background: #0f3a1d;
        color: #b9f7d4;
        box-shadow: 0 0 15px rgba(48, 197, 114, 0.45);
    }
    </style>
    """,
    unsafe_allow_html=True,
)


def fmt(value: float) -> str:
    return f"{value:.3f}"


def round_three(value: float) -> float:
    return float(f"{value:.3f}")


def metric_card(label: str, value: str, footer: str | None = None) -> None:
    footer_html = f'<div class="metric-footer">{footer}</div>' if footer else ""
    st.markdown(
        f"""
        <div class="metric-card">
            <div class="metric-label">{label}</div>
            <div class="metric-value">{value}</div>
            {footer_html}
        </div>
        """,
        unsafe_allow_html=True,
    )


def action_button(title: str, price: str, description: str, *, key: str, active: bool) -> bool:
    wrapper_class = "action-button active" if active else "action-button"
    st.markdown(f"<div class='{wrapper_class}'>", unsafe_allow_html=True)
    label = f"{title}\nCost: {price}\n{description}"
    clicked = st.button(
        label,
        key=key,
        use_container_width=True,
        disabled=active,
    )
    st.markdown("</div>", unsafe_allow_html=True)
    return clicked


def get_hospital() -> Hospital:
    if "hospital" not in st.session_state:
        st.session_state.hospital = Hospital()
    return st.session_state.hospital


def restart_simulation() -> None:
    st.session_state.hospital = Hospital()
    st.success("Simulation reset")
    st.rerun()


def perform_action(result: tuple[bool, str]) -> None:
    ok, message = result
    if ok:
        st.success(message)
        st.rerun()
    else:
        st.warning(message)


REFERENCE_ROWS = get_reference_rows()

hospital = get_hospital()
summary = hospital.summary()

with st.sidebar:
    st.header("Simulation Controls")
    st.caption("Advance time to process admissions, treatment, and events.")
    col_a, col_b = st.columns(2)
    if col_a.button("+1 hour"):
        hospital.advance_hours(1)
        st.rerun()
    if col_b.button("+6 hours"):
        hospital.advance_hours(6)
        st.rerun()
    if st.button("+24 hours"):
        hospital.advance_hours(24)
        st.rerun()
    if st.button("Reset Simulation", type="secondary"):
        restart_simulation()

    st.markdown("---")
    st.subheader("At a glance")
    metric_card("Funds", f"${summary['money']:,}")
    metric_card("Infection Risk", f"{summary['infection_risk']*100:.3f}%")
    metric_card("Score", f"{summary['score']}")

st.title("COVID CRACKDOWN: Isolationism")
st.caption("Outthink every pathogen, ration every vial, and keep the ward breathing.")

if summary["end_condition"]:
    st.error(f"Simulation ended: {summary['end_condition']}")
    if st.button("Start New Run"):
        restart_simulation()


tabs = st.tabs([
    "Dashboard",
    "Patients",
    "Treatments",
    "Diagnostics Reference",
    "Supplies",
    "Policies & Upgrades",
])

# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------
with tabs[0]:
    col1, col2, col3 = st.columns(3)
    with col1:
        metric_card("Day", str(summary["day"]))
        metric_card("Hour", f"{summary['hour']:02d}:00")
    with col2:
        metric_card(
            "General Beds",
            f"{summary['general']['used']}/{summary['general']['capacity']}",
        )
        metric_card(
            "Isolation Beds",
            f"{summary['isolation']['used']}/{summary['isolation']['capacity']}",
        )
    with col3:
        metric_card(
            "Ventilators",
            f"{summary['vents']['free']}/{summary['vents']['total']}",
        )
        metric_card("Staff Available", str(summary["staff"]["staff"]))

    kpi_cols = st.columns(3)
    with kpi_cols[0]:
        metric_card("Recoveries", str(summary["stats"]["discharges"]))
    with kpi_cols[1]:
        metric_card("Deaths", str(summary["stats"]["deaths"]))
    with kpi_cols[2]:
        metric_card("Hospital-acquired cases", str(summary["stats"]["infections"]))

    hist = summary["history"]
    if hist["recoveries"]:
        history_df = pd.DataFrame(
            {
                "Recoveries": hist["recoveries"],
                "Infections": hist["infections"],
                "Deaths": hist["deaths"],
            }
        )
        st.subheader("Cumulative Trends")
        st.line_chart(history_df)

    st.subheader("Message Log")
    st.text("\n".join(summary["messages"] or ["No events yet."]))

# ---------------------------------------------------------------------------
# Patients Tab
# ---------------------------------------------------------------------------
with tabs[1]:
    active_patients = hospital.get_active_patients()
    if not active_patients:
        st.info("No active patients. Advance time to receive new admissions.")
    else:
        patient_rows = []
        for p in active_patients:
            patient_rows.append(
                {
                    "ID": p.id,
                    "Name": p.name,
                    "Ward": p.ward,
                    "COVID Status": p.covid_status,
                    "Actual": p.actual_covid_status if p.tested else "?",
                    "SpO2": round_three(p.vitals["spo2"]),
                    "Temp": round_three(p.vitals["temp"]),
                    "RR": round_three(float(p.vitals["rr"])),
                    "Diagnosis": p.infection_label if p.diagnosis_known else "Unknown",
                    "Clinical Notes": "; ".join(p.clinical_notes[:2]) if p.clinical_notes else "",
                    "Ward Notes": "; ".join(p.notes[:2]) if p.notes else "",
                }
            )
        st.dataframe(pd.DataFrame(patient_rows), width="stretch", hide_index=True)

        patient_ids = [p.id for p in active_patients]
        selected_id = st.selectbox(
            "Select patient",
            patient_ids,
            format_func=lambda pid: f"{pid} - {hospital.get_patient(pid).name}",
        )
        selected_patient = hospital.get_patient(selected_id)
        col_a, col_b, col_c, col_d = st.columns(4)
        if col_a.button("Run COVID Test"):
            perform_action(hospital.run_test(selected_id))
        if col_b.button("Admit to General Ward"):
            perform_action(hospital.admit_patient(selected_id, "general"))
        if col_c.button("Admit to Isolation Unit"):
            perform_action(hospital.admit_patient(selected_id, "isolation"))
        if col_d.button("Order Infection Panel"):
            perform_action(hospital.order_infection_panel(selected_id))

        if selected_patient:
            st.write(
                f"COVID Status: {selected_patient.covid_status} · Confirmed Infection: "
                f"{selected_patient.infection_label if selected_patient.diagnosis_known else 'Unknown'}"
            )
            st.write(
                f"Requires Isolation: {'Yes' if selected_patient.covid_status == 'positive' else 'No'}"
            )
            if selected_patient.clinical_notes:
                st.markdown(
                    "**Clinical Notes:** " + "; ".join(selected_patient.clinical_notes[:3])
                )
            if selected_patient.notes:
                st.markdown(
                    "**Ward Notes:** " + "; ".join(selected_patient.notes[:3])
                )

# ---------------------------------------------------------------------------
# Treatments Tab
# ---------------------------------------------------------------------------
with tabs[2]:
    active_patients = hospital.get_active_patients()
    if not active_patients:
        st.info("No patients available.")
    else:
        patient_map = {p.id: p for p in active_patients}
        treatment_patient_id = st.selectbox(
            "Patient for treatment decisions",
            list(patient_map.keys()),
            format_func=lambda pid: f"{pid} - {patient_map[pid].name}",
            key="treatment_select",
        )
        patient = patient_map[treatment_patient_id]
        vitals_cols = st.columns(5)
        with vitals_cols[0]:
            metric_card("SpO2", f"{fmt(patient.vitals['spo2'])}%")
        with vitals_cols[1]:
            metric_card("Temp", f"{fmt(patient.vitals['temp'])}°C")
        with vitals_cols[2]:
            metric_card("RR", fmt(float(patient.vitals["rr"])))
        with vitals_cols[3]:
            metric_card("HR", fmt(float(patient.vitals["hr"])))
        with vitals_cols[4]:
            metric_card("BP", fmt(float(patient.vitals["bp"])))
        st.write(f"Severity: {fmt(patient.severity)} · Ward: {patient.ward}")
        st.write(f"Symptoms: {', '.join([sym for sym, present in patient.symptoms.items() if present]) or 'None'}")
        st.write(f"Risk factors: Age {patient.risk['age']}, {patient.risk['comorbidity']}")

        treatment_cols = st.columns(len(TREATMENTS))
        for idx, (key, treatment) in enumerate(TREATMENTS.items()):
            with treatment_cols[idx]:
                is_active = patient.treatments.get(key, False)
                toggle_key = f"treat_{patient.id}_{key}"
                if st.toggle(treatment.label, value=is_active, key=toggle_key) != is_active:
                    perform_action(hospital.toggle_treatment(patient.id, key))
                st.caption(treatment.description)

# ---------------------------------------------------------------------------
# Diagnostics Reference Tab
# ---------------------------------------------------------------------------
with tabs[3]:
    st.subheader("Differential Cheat Sheet")
    st.caption("Compare symptoms, vitals, and quarantine rules before committing to isolation.")
    st.markdown(
        "<style>"
        ".ref-card {border: 1px solid #555; border-radius: 10px; padding: 1rem; margin-bottom: 1rem; background-color: #0c111a;}"
        ".ref-card strong {color: #fefefe;}"
        ".ref-card ul {margin: 0.35rem 0 0.35rem 1.5rem;}"
        "</style>",
        unsafe_allow_html=True,
    )
    for reference in REFERENCE_ROWS:
        complaints = [
            item.strip()
            for item in reference["Chief Subjective Complaints"].split(";")
            if item.strip()
        ]
        complaints_list = "".join(f"<li>{c}</li>" for c in complaints)
        st.markdown(
            f"""
            <div class="ref-card">
                <div><strong>{reference['Pathogen']}</strong> · {reference['Type']}</div>
                <div><strong>Quarantine?</strong> {reference['Quarantine?']}</div>
                <div><strong>Signature Symptoms:</strong> {reference['Signature Symptoms']}</div>
                <div><strong>Vital Clues:</strong> {reference['Vital Clues']}</div>
                <div><strong>Chief Subjective Complaints</strong></div>
                <ul>{complaints_list}</ul>
            </div>
            """,
            unsafe_allow_html=True,
        )
    st.markdown(
        "Use these ranges to justify testing decisions. Quarantine beds are reserved for lab-confirmed COVID cases,"
        " so align clinical notes with vitals, order tests, and transfer patients once confidence thresholds are met."
    )

# ---------------------------------------------------------------------------
# Supplies Tab
# ---------------------------------------------------------------------------
with tabs[4]:
    supplies = summary["supplies"]
    stock_cols = st.columns(4)
    keys = ["tests", "ppe", "meds", "vaccines"]
    for idx, key in enumerate(keys):
        with stock_cols[idx]:
            metric_card(key.upper(), str(supplies["stock"].get(key, 0)))

    order_cols = st.columns(len(keys))
    for idx, key in enumerate(keys):
        template = supplies["catalog"][key]
        label = f"Order {template['label']} (x{template['qty']})"
        if order_cols[idx].button(label):
            perform_action(hospital.order_supply(key))

    st.markdown("### Pending Orders")
    if supplies["orders"]:
        st.table(pd.DataFrame(supplies["orders"]).round(3))
    else:
        st.write("No orders in transit.")

    if st.button("Deploy Vaccination Drive (uses 2 vials)"):
        perform_action(hospital.deploy_vaccination())

# ---------------------------------------------------------------------------
# Policies & Upgrades
# ---------------------------------------------------------------------------
with tabs[5]:
    st.subheader("Policies")
    for key, policy in summary["policies"].items():
        if action_button(
            policy["label"],
            f"${policy['cost']:,}",
            policy["description"],
            key=f"policy_{key}",
            active=policy["active"],
        ):
            perform_action(hospital.toggle_policy(key))

    st.subheader("Upgrades")
    for key, upgrade in summary["upgrades"].items():
        if action_button(
            upgrade["label"],
            f"${upgrade['cost']:,}",
            upgrade["effect"],
            key=f"upgrade_{key}",
            active=upgrade["purchased"],
        ):
            perform_action(hospital.buy_upgrade(key))
