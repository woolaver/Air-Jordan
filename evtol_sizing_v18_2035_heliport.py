# -*- coding: utf-8 -*-
"""
===============================================================================
 v18: alignment with J.R.R.A. Martins, "The Metabook of Aircraft Design"
      (AE481, U-M, 2021) wherever the method applies to a lift+cruise STOL:
      (1) propeller efficiency in every thrust-power energy integral
          (cruise, climb, reserves, electric trips; Metabook Eq. 2.20-2.21);
          descent energy no longer multiplied by eta_prop;
      (2) high-lift / gear drag and span efficiency from Table 4.2
          (take-off flaps, landing flaps, landing gear), take-off flap setting
          used in ALL take-off simulations (idempotent p_takeoff);
      (3) wing-CL margins from Sec. 4.4: take-off 1.1 Vs (CL <= CLmax/1.21),
          approach 1.3 Vs (CL <= CLmax/1.69) for the wing share of the lift;
      (4) FAR 23.2120 a/b/c climb checks as listed in Sec. 4.7.2 (take-off /
          landing configuration, gear, CLmax - 0.2 margin); OEI pusher-lane
          sizing in the same configuration;
      (5) service-ceiling climb capability (Sec. 4.8, G > 0);
      (6) cruise at <= 80 % of rated power for pusher and genset (Eq. 4.41);
      (7) limit load factor from Eq. 11.3 and gust load factor from
          Eqs. 11.4-11.7 (V_D = 1.25 V_C, Sec. 11.3.2), n_ult = 1.5 n_lim;
      (8) wing mass = max(bending model, Raymer Eq. 7.11 x composite fudge
          factor of Table 7.5);
      (9) report prints Metabook cross-checks (Table 7.1 empty-weight
          buildup bracket, Roskam Eq. 7.20 turboshaft mass, load factors).
      NOT changed (Metabook not applicable or RFP governs): rotor/hover
      physics, powered-lift take-off/landing, 100 kg per occupant (RFP),
      explicit IFR reserves instead of the 1.06 factor, Cf (within the
      Fig. 4.4 bracket), motor/turboshaft specific power (own 2035 data,
      Sec. 7.3.3), airframe regression (cross-checked, see report).
===============================================================================
 v17b: (1) all outputs always go to the user's Downloads folder (Windows,
       macOS, Linux); (2) new hard constraint W/S <= 4200 N/m^2
       (Requirements.ws_max, check "WS_max"); (3) the current design is saved
       as a spec table (CSV + XLSX if openpyxl is installed + PNG) next to the
       dimensioned multi-view drawing; (4) take-off time history plots
       (lift share wing / lift rotors, rate of climb, ground speed, height
       over time since brake release AND over distance over ground).
       All other values and settings unchanged.
===============================================================================
 EVTOL-SIZE v15 -- 2035 optimistic E-STOL sizing / performance / energy / cost tool
 v15: EIS-2035 optimistic technology case: 500 Wh/kg pack, 225 kt target, 200 nmi
       electric mission segment, realistic-but-optimistic 130 kg aircraft systems
       allowance, small performance/response margins, and a 15.2 m span design cap.
       Unpressurised cabin only (no cabin
      compressor, no ECS pressurisation hardware, no pressure-vessel mass),
      cruise altitude <= 12,500 ft (crew without supplemental oxygen),
      cruise at the RFP minimum of 225 kt, objective = low MTOW + low energy.
 v13: two aircraft variants sized side by side
        "P" pressurised cabin, cruise altitude free (<= 30,000 ft)
        "U" unpressurised cabin, cruise altitude <= 12,500 ft (no O2 needed)
      and flown on (a) the 400 nmi design mission (hybrid) and (b) a 200 nmi
      point-to-point trip entirely on the battery (battery reserve allowed to
      be used, IFR fuel reserve on board), incl. all system loads.
 v12: cabin pressurisation and on-board systems priced in (optimistic):
      bleed-less electric ECS (electric cabin-air compressor, ram-air heat
      exchanger, vapour-cycle cooling, outflow valve), pressure-vessel
      structure penalty, avionics / FBW computers / lights / actuators /
      thermal-management pumps. Mass add-ons + electric power in every flight
      phase (genset on the fuel legs, battery on the electric legs and in the
      reserve), generator sized for the extra load.
 v11: fast descent: glide unpowered while the natural glide rate at the
      descent speed stays below the target rate of descent; below that the
      descent speed is held with just enough power (power-on descent) -> short
      block time without wasting energy. Point-to-point all-electric missions
      (take-off, climb, cruise at 230 kt, descent, landing on the battery):
      maximum range vs cruise altitude, with and without the battery reserve.
 v10: electric cruise 180 nmi (+50 nmi reserve); bending-based wing mass
      (spar caps sized by the manoeuvre load OR the rotor/boom hover and
      landing load, spar depth = t/c * chord -> high AR and big booms cost
      mass); rotor drag and boom position scale with rotor diameter;
      two-stage search (fast surrogate for take-off/landing energy on a wide
      grid, full physics only for the best candidates); one-at-a-time and
      profile studies of AR, W/S, rotor diameter, cruise altitude;
      dimensioned multi-view drawing of the final design
 v9: (a) lift rotors with 2 independent motors each (lift_lanes = 2): the
         critical lift failure becomes ONE MOTOR of one rotor ("lane");
     (b) aggressive high-lift: double-slotted flaps + leading-edge slats
         (HIGHLIFT presets, Raymer ch. 12 increments), more flap drag + mass;
     (c) configuration matrix: V1 feasibility, take-off energy, MTOW and the
         landing failure window for all four combinations
 v8: three-phase take-off with V1 (see takeoff3_sim / v1_analysis):
     automated emergency response (no recognition time); before V1 a lift-rotor
     or pusher-lane failure -> land and stop within 300 ft; after V1 -> clear
     50 ft at 300 ft with the failure and fly away. The tool finds the smallest
     lift-rotor power margin (or uses the emergency rating) that makes one V1
     valid for both failure types.
 v7: DESIGN take-off = ground roll, decision point = lift-off:
       * lift-rotor failure just BEFORE lift-off -> brake, stop within 300 ft
       * lift-rotor failure just AFTER lift-off  -> safe continued take-off
     both are hard constraints on the take-off law (V_lof, rotor unloading);
     ALTERNATIVE take-off = helicopter-style VTOL (vertical climb, then
     acceleration) for runway-less / off-design missions, with its energy
     penalty, the effect on electric range and a 5000 ft hot-day check
 v6: (1) take-off mode "roll": ground roll on the wheels (pusher + optionally
         forward-tilted, partly unloading rotors) before lift-off, compared
         with the v5 "hover" lift-off; (2) objective includes flight time via
         a value of passenger time (generalised cost), cruise speed is a design
         variable (>= 225 kt); (3) time-domain landing; (4) standard and
         emergency take-off / landing simulations with physics plots
 v5: critical loss of thrust (CLoT) -- lift-rotor failure during take-off and
     landing (reject / continue / height-velocity avoid zone, TDP and LDP),
     dual-lane pusher (Vaeridion-style: two motors, one propeller) with
     one-lane climb, cruise and glide checks
 hybrid lift + cruise: 4 lift rotors (tiltable a few degrees) + 1 pusher
===============================================================================
 v4 changes
   * fast: closed-form hover, fixed-point rotor inflow, cached take-off in the
     mass loop, small default grid  -> whole run in well under a minute
   * battery 400 Wh/kg (pack), cruise 230 kt, cruise altitude <= 30,000 ft,
     MTOW <= 6000 kg (hard constraints)
   * electric: 150 nmi electric cruise + 50 nmi electric reserve (= 200 nmi)
   * descent: pure glide at best L/D, no energy used
   * NEW TAKE-OFF ("rolling vertical" STOL):
       all 5 propulsors at full power from brake release; after lift-off the
       lift rotors are tilted forward by up to theta_max so they accelerate
       the aircraft as well as lift it; the wing carries as much weight as its
       usable CL allows; the vertical speed is chosen by bisection so that the
       50 ft obstacle is cleared EXACTLY at 300 ft; then the aircraft keeps
       accelerating until the wing carries everything and the rotors stop.
       The tilt limit and the climb rate after the obstacle are optimised
       for minimum take-off energy on the final design.
   * landing: glide to the approach, then rotor-supported deceleration and a
     short vertical touchdown (a power-off STOL landing is checked and shown)
 Requirements fixed in class Requirements, assumptions in class P.
 Run: python3 evtol_sizing_v4.py
===============================================================================
"""
from dataclasses import dataclass, replace
from pathlib import Path
import csv, datetime, math, os, time
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

G, RHO0, FT, KT, NMI, LB, HP, WH = 9.80665, 1.225, 0.3048, 1852 / 3600, 1852.0, 0.45359237, 745.7, 3600.0
LHV = 43.0e6
# [v17b] always the user's Downloads folder (C:/Users/<name>/Downloads on Windows)
_DL = Path.home() / "Downloads"
_DL.mkdir(parents=True, exist_ok=True)
OUT = _DL.as_posix() + "/"


# =============================================================================
#  FIXED REQUIREMENTS (RFP 2026-27 + your design limits)
# =============================================================================
@dataclass(frozen=True)
class Requirements:
    n_occupants: int = 8
    mass_person: float = 100.0            # 190 lb + 30 lb baggage
    range_total: float = 400.0            # nmi design mission
    range_el_cruise: float = 170.0            # [O] target electric range in mission        # nmi electric cruise in the mission [v10]
    range_el_reserve: float = 0.0        # nmi electric reserve (battery only)
    v_cruise: float = 225.0 * KT          # RFP minimum
    h_max: float = 12000.0 * FT           # your ceiling
    mtow_max: float = 6000.0              # kg, your limit
    roc_min: float = 1500.0 * FT / 60     # sea level ISA+18, all engines
    grad_min: float = 0.04                # Part 23 AEO initial climb gradient
    s_field: float = 300.0 * FT           # take-off / landing distance
    h_obs: float = 50.0 * FT
    dT_isa: float = 10.0                  # ISA+18 degF
    h_field_high: float = 5000.0 * FT
    time_hold: float = 0.5                # h IFR fuel reserve
    range_alternate: float = 50.0         # nmi IFR fuel reserve
    ws_max: float = 4200.0                # [v17b] N/m^2 upper wing-loading limit


REQ = Requirements()


def isa_rho(h, dT=None):
    dT = REQ.dT_isa if dT is None else dT
    return 101325.0 * (1 - 2.25577e-5 * h) ** 5.25588 / (287.053 * (288.15 - 0.0065 * h + dT))


# =============================================================================
#  INPUT PARAMETERS
# =============================================================================
@dataclass
class P:
    # 2035 design targets / optional special-use heliport ConOps
    target_cruise: float = 225.0             # kt, RFP objective
    target_mtow: float = 5800.0              # kg, AIAA conceptual design target
    span_max: float = 15.2                   # m, preferred compact-aircraft envelope
    heli_approach_deg: float = 18.0          # deg, optional special-use heliport approach target
    # FAA EB 105A reference-aircraft envelope for optional VTOL/vertiport ConOps
    heliport_mtow_max: float = 5670.0        # kg
    heliport_cd_max: float = 15.2            # m controlling dimension
    battery_systems: int = 2                 # independent HV battery systems
    heliport_prop_units: int = 5             # 4 lift + 1 pusher
    heliport_vmc: bool = True
    heliport_control_augmented: bool = True
    # propulsion components
    # Optimistic 2035 aircraft-installed technology assumptions; document against RFP trend refs.
    sp_motor: float = 8.0; sp_inverter: float = 20.0          # kW/kg
    sp_generator: float = 12.0; sp_turboshaft: float = 5.0    # kW/kg
    m_rotor: float = 25.0; k_rotor_D: float = 2.2             # kg at D=4 m
    m_boom: float = 30.0; m_push_prop: float = 45.0
    f_cool: float = 0.10
    # ---- [v5] redundancy / critical loss of thrust -------------------------
    lift_lanes: int = 2                   # [v9] 2 independent motors per lift rotor
    k_lane_mass: float = 0.15             # mass add-on per extra lane (+15 %)
    push_lanes: int = 2                   # two motors on one pusher propeller
    k_push_combiner: float = 1.10         # gearbox/combiner + 2nd inverter
    k_em_lift: float = 1.30               # 30-s emergency power of a lift lane
    k_em_push: float = 1.20               # emergency power of a pusher lane
    grad_oei: float = 0.01                # Part 23 L3 low-speed CLoT climb (lecture)
    t_recog: float = 0.25                  # s -- [v8] automated emergency response
    V_ctrl: float = 60.0 * KT             # speed at which aero controls can
    #                                       trim a full one-rotor imbalance
    w_td_emerg: float = 3.0               # m/s survivable touchdown sink (gear)
    f_rev_push: float = 0.30              # pusher reverse thrust share (braking)
    mu_brake: float = 0.45
    L_runway: float = 300.0 * FT          # runway available for a reject
    eta_motor: float = 0.97; eta_inverter: float = 0.995; eta_cable: float = 0.997
    eta_generator: float = 0.98; eta_batt: float = 0.97; eta_prop: float = 0.85
    FM: float = 0.82; kappa: float = 1.15; tip_speed: float = 190.0
    sfc: float = 0.38; n_lapse: float = 0.75
    D_push: float = 2.6
    # battery
    # 500 Wh/kg pack is an optimistic-but-supported 2035 scenario, not current SoA.
    # 2035 studies cited by the RFP use 500 Wh/kg pack-level values as achievable/advanced.
    e_pack: float = 420.0 * WH; dod: float = 0.90; p_pack: float = 2.2
    f_gen_takeoff: float = 1.0            # genset feeds the bus at take-off
    # aerodynamics
    Cf: float = 0.0035; k_misc: float = 1.10; e_clean: float = 0.85
    CLmax_clean: float = 1.60; dCLmax_flap: float = 1.0; dCD0_flap: float = 0.065
    dCLmax_nose: float = 0.0; dCD0_nose: float = 0.0   # [v9] slats
    # [v9] take-off flap setting: share of the landing-setting CL increment
    # and of its drag increment (partial deflection, slats fully out)
    f_TO_CL: float = 0.65
    # [v18] Metabook Table 4.2 (Roskam Part I, Tab. 3.6), mid values:
    # landing flaps dCD0 0.055-0.075, e 0.70-0.75; take-off flaps
    # dCD0 0.010-0.020, e 0.75-0.80; landing gear dCD0 0.015-0.025
    dCD0_TO: float = 0.015                # total take-off high-lift increment
    e_TO: float = 0.775
    dCD0_gear: float = 0.020              # gear down on landing; on take-off up to 50 ft
    e_highlift: float = 0.725             # landing configuration
    # [v18] wing-CL margins, Metabook Sec. 4.4: V_TO ~ 1.1 Vs, V_app = 1.3 Vs
    k_CL_TO: float = 1 / 1.1 ** 2
    k_CL_trans: float = 1 / 1.3 ** 2      # approach / landing (and default)
    dCL_climb: float = 0.2                # Sec. 4.7.2: CL = CLmax - 0.2 in climb
    roc_ceiling: float = 100.0 * FT / 60  # Sec. 4.8 asks G > 0; 100 fpm = service ceiling
    f_cruise_rating: float = 0.80         # Eq. 4.41: cruise ~75-80 % of rated power
    _to_cfg: bool = False                 # internal: take-off setting applied
    f_rot_spin: float = 0.10; f_rot_stop: float = 0.02         # m^2 per rotor
    CL_cruise_max: float = 0.80
    # structure
    rho_wing: float = 12.2; m_flap_sys: float = 1.5
    # [v10] bending-based wing mass (spar caps + webs + skins)
    wing_model: str = "bending"           # "bending" or "areal" (v9)
    t_c: float = 0.14                     # thickness ratio at the root
    taper: float = 0.6
    n_ult: float = 0.0                    # [v18] 0 = from Metabook Eq. 11.3 / 11.4 (x1.5)
    wing_model_check: bool = True         # [v18] max(bending, Raymer Eq. 7.11)
    k_wing_comp: float = 0.85             # Table 7.5 composite wing 0.85-0.90
    f_csw: float = 0.30                   # control surfaces incl. flaps / S (assumed)
    n_hover_ult: float = 3.0              # rotor/boom load case (hard landing, gust)
    sigma_cap: float = 600e6              # Pa allowable CFRP spar caps (ultimate)
    rho_cap: float = 1600.0               # kg/m^3
    k_web: float = 1.30                   # webs, joints, root fitting
    rho_skin: float = 6.0                 # kg/m^2 skins, ribs, secondary
    # [v10] fast surrogate for take-off / landing energy (calibrated on v9)
    k_to_E: float = 28.5                  # J per W of installed lift power
    k_la_E: float = 3.3
    # [v12] cabin pressurisation + on-board systems (optimistic 2035)
    pressurised: bool = False             # [v14] unpressurised only
    h_cabin_max: float = 8000.0 * FT      # max cabin altitude (CS/FAR 25 practice)
    m_air_occ: float = 0.25 / 60          # kg/s fresh air per occupant (25.831)
    k_leak: float = 1.4                   # total compressor flow / fresh-air flow
    eta_comp: float = 0.78                # electric cabin compressor, isentropic
    eta_aux_drive: float = 0.93           # aux motor + inverter
    q_occ: float = 100.0                  # W heat per occupant
    q_solar: float = 1500.0               # W solar + wall heat on the ground
    COP_vc: float = 2.5                   # vapour-cycle cooling
    P_avionics: float = 900.0             # W IFR avionics, FBW computers, autopilot
    P_lights: float = 250.0               # W LED nav/strobe/landing/cabin
    P_actuators: float = 600.0            # W average EMA flight controls, flaps, tilt
    P_cabin: float = 300.0                # W cabin systems, displays, galley-less
    f_tms: float = 0.004                  # TMS pumps/fans, share of shaft power
    m_press_struct: float = 0.0           # [v14] no pressure vessel
    m_ecs: float = 0.0                    # [v14] no pressurisation ECS (cooling unit kept in m_aux_electric)
    # optimistic complete non-propulsive electrical/avionics/actuator allowance
    # (see systems_mass_breakdown_2035 below)
    m_aux_electric: float = 120.0
    # [v11] descent law
    V_desc: float = 0.0                   # m/s TAS in the descent (0 = cruise speed)
    rod_target: float = 2000.0 * FT / 60  # target rate of descent (pressurised cabin)
    h_desc_end: float = 1500.0 * FT       # end of the en-route descent (approach follows)
    AR_max: float = 18.0                  # [v10] cap: flutter/stiffness with wing
    #                                       booms + rotors is not modelled
    k_airframe: float = 0.9; k_struct: float = 1.03
    # take-off law (defaults used inside the sizing loop; optimised at the end)
    theta_max: float = 30.0               # deg forward tilt of the lift rotors
    w_after_obs: float = 7.5              # m/s climb rate after the obstacle
    # [v5] "low-and-fast" profile to stay out of the H-V avoid zone:
    # hold h_low until V_rot, only then climb to the obstacle (0 = off)
    h_low: float = 1.0                    # m   (default: ON, see CLoT study)
    V_rot: float = 30.0 * KT              # m/s
    # [v5] landing: "rolling" = decelerate to V_app above the obstacle, steep
    # approach at V_app (wing + rotors, rotor-failure safe), short roll with
    # wheel brakes + pusher reverse; "vertical" = v4 behaviour
    landing_mode: str = "rolling"
    V_app: float = 35.0 * KT
    s_flare: float = 14.0                 # m reserved for the flare in the landing
    # ---- [v6] take-off mode ------------------------------------------------
    to_mode: str = "roll"                 # "roll" (design), "vtol" or "hover"
    h_vtol: float = 50.0 * FT + 5.0       # [v7] vertical climb height in VTOL mode
    vz_vtol: float = 2.5                  # [v7] vertical climb rate (power-limited)
    V_accel_climb: float = 60.0 * KT      # [v7] VTOL: level acceleration up to here
    k_vtol_margin: float = 1.05            # [v7] >1 sizes rotors for VTOL climb margin
    V_lof: float = 30.0 * KT              # lift-off speed in "roll" mode
    f_unload: float = 0.5                 # share of W carried by rotors on the roll
    theta_ground: float = 30.0            # deg rotor tilt during the roll
    mu_roll: float = 0.03                 # rolling friction, paved
    # ---- [v6] cruise speed and time value ----------------------------------
    v_cruise: float = 230.0 * KT          # design variable (>= REQ 225 kt)
    VOT: float = 60.0                     # $/h value of time per passenger
    t_taxi: float = 0.15                  # h taxi + procedures per flight
    k_download: float = 1.05
    # operations
    e_ground: float = 15.0e3 * WH
    v_climb: float = 150.0 * KT
    v_hold: float = 130.0 * KT; h_hold: float = 5000.0 * FT
    Vz_down: float = 2.0; h_trans: float = 20.0
    # cost placeholders
    c_batt: float = 150.0; n_cycles: float = 1500.0
    c_motor: float = 100.0; c_inverter: float = 50.0; c_genset: float = 400.0
    c_airframe: float = 1200.0; c_elec: float = 0.15; c_fuel: float = 1.0
    c_maint: float = 150.0; life_h: float = 20000.0
    w_mass: float = 0.5; w_energy: float = 0.5; w_cost: float = 0.0   # [v14] MTOW + energy


def CLhl(p):
    """[v9] CLmax with flaps and slats deployed."""
    return p.CLmax_clean + p.dCLmax_flap + p.dCLmax_nose


def dCD0hl(p, gear=True):
    """High-lift (+ landing gear) drag increment, Metabook Table 4.2."""
    return p.dCD0_flap + p.dCD0_nose + (p.dCD0_gear if gear else 0.0)


def p_takeoff(p):
    """[v9/v18] parameter set with the take-off flap setting (Table 4.2) and
    the 1.1 Vs wing-CL margin (Sec. 4.4). Idempotent."""
    if p._to_cfg:
        return p
    return replace(p, dCLmax_flap=p.dCLmax_flap * p.f_TO_CL,
                   dCD0_flap=p.dCD0_TO, dCD0_nose=0.0, e_highlift=p.e_TO,
                   k_CL_trans=p.k_CL_TO, _to_cfg=True)


def lift_fmode(p):
    """[v9] critical lift-system failure: one motor lane or the whole rotor."""
    return "lane" if p.lift_lanes > 1 else "rotor"


# [v9] high-lift presets (3-D increments ~ 0.9*dCl*S_flapped/S, Raymer ch. 12)
HIGHLIFT = {
    # [v18] drag / e from Metabook Table 4.2: single slotted = mid of range,
    # double slotted + slats = high-drag / low-e end of range
    "single-slotted flap": dict(dCLmax_flap=1.0, dCLmax_nose=0.0, dCD0_flap=0.065,
                                dCD0_nose=0.0, dCD0_TO=0.015, e_highlift=0.725,
                                e_TO=0.775, m_flap_sys=1.5),
    "double-slotted flap + slats": dict(dCLmax_flap=1.4, dCLmax_nose=0.5, dCD0_flap=0.070,
                                        dCD0_nose=0.005, dCD0_TO=0.020, e_highlift=0.70,
                                        e_TO=0.75, m_flap_sys=3.5),
}



SYSTEMS_MASS_2035 = {
    "IFR avionics + FBW": 22.0,
    "HV distribution + protection": 20.0,
    "HV wiring + connectors": 15.0,
    "BMS + monitoring": 10.0,
    "battery thermal management": 25.0,
    "flight controls + tilt actuators": 15.0,
    "oxygen + emergency equipment": 8.0,
    "misc. electrical/cabin equipment": 5.0,
}

def systems_mass_breakdown_2035():
    return dict(SYSTEMS_MASS_2035), sum(SYSTEMS_MASS_2035.values())

def aux_power(p, h, P_shaft=0.0):
    """[v12] electric power of the non-propulsive systems at altitude h.
    Cabin compressor: fresh air (25.831) x leakage, compressed from ambient
    to cabin pressure (cabin altitude <= h_cabin_max), ideal gas, eta_comp.
    Cooling: occupants + avionics + solar, vapour cycle with COP_vc (compressed
    air is hot, the ram-air HX dumps the compression heat).
    Returns (total W, dict of components)."""
    comp = 0.0                                               # [v14] no cabin compressor
    heat = p.q_occ * REQ.n_occupants + p.P_avionics + (p.q_solar if h < 1000 else 300.0)
    cool = heat / p.COP_vc / p.eta_aux_drive
    fans = mdot_fan = 150.0                                    # recirculation fans
    tms = p.f_tms * P_shaft
    parts = dict(cooling=cool, recirc_fans=fans, avionics=p.P_avionics,
                 lights=p.P_lights, actuators=p.P_actuators, cabin=p.P_cabin, thermal_mgmt=tms)
    return sum(parts.values()), parts


def descent_profile(ac, p, W, h_top, V=None, n=30):
    """[v11] descent from h_top to h_desc_end at constant TAS V.
    At every step the natural glide rate V/(L/D) is compared with the target
    rate of descent: if the glide is shallower or equal -> unpowered glide at
    that rate (no energy); if the glide is steeper -> hold rod_target with
    power P = (D - W*rod/V)*V/eta_prop. Returns distance [nmi], time [s],
    battery-side energy [J] and the powered share of the descent."""
    V = V if V else (p.V_desc if p.V_desc > 0 else max(p.v_cruise, REQ.v_cruise))
    hs = np.linspace(h_top, p.h_desc_end, n + 1)
    dist = t = E = t_pow = 0.0
    for h1, h2 in zip(hs[:-1], hs[1:]):
        hm = 0.5 * (h1 + h2)
        ld, _ = LD(ac, W, V, hm)
        rod_glide = V / ld
        if rod_glide <= p.rod_target:
            rod, P = rod_glide, 0.0
        else:
            rod = p.rod_target
            D = W / ld
            P = max((D - W * rod / V) * V / p.eta_prop, 0.0)
        dt = (h1 - h2) / rod
        dist += V * math.cos(math.asin(min(rod / V, 0.5))) * dt
        t += dt
        E += P / eta_batt_shaft(p) * dt if P > 0 else 0.0
        t_pow += dt if P > 0 else 0.0
    return dist / NMI, t, E, t_pow / max(t, 1e-9)


def cl_alpha(AR, M=0.0, sweep_half=0.0, kappa=0.97):
    """Lift-curve slope, DATCOM expression (Metabook Eq. 11.6-11.7)."""
    beta = math.sqrt(max(1 - M * M, 1e-6))
    return 2 * math.pi * AR / (2 + math.sqrt((AR * beta / kappa) ** 2
                                             * (1 + math.tan(sweep_half) ** 2 / beta ** 2) + 4))


def gust_velocities(h):
    """Ue at V_B, V_C, V_D [ft/s], Metabook Table 11.1 (linear 20-50 kft)."""
    f = min(max((h / FT - 20000.0) / 30000.0, 0.0), 1.0)
    return 66 - 28 * f, 50 - 25 * f, 25 - 12.5 * f


def design_load_factor(p, W, S, AR, V_tas, h):
    """Limit load factors, Metabook Sec. 11.3:
    manoeuvre Eq. 11.3 (need not exceed 3.8), gust Eq. 11.4-11.5 (Pratt)
    at V_B (stall/gust intersection), V_C (= cruise EAS) and V_D = 1.25 V_C.
    Returns (n_manoeuvre, n_gust, n_ult = 1.5 * max)."""
    W_lb = W / G / LB
    n_man = min(2.1 + 24000.0 / (W_lb + 10000.0), 3.8)
    rho = isa_rho(h)
    T = 288.15 - 0.0065 * h + REQ.dT_isa
    M = V_tas / math.sqrt(1.4 * 287.053 * T)
    a = cl_alpha(AR, M)
    b = math.sqrt(AR * S)
    mu = 2 * (W / S) / (rho * (S / b) * a * G)
    Kg = 0.88 * mu / (5.3 + mu)
    ws_psf = (W / S) * FT ** 2 / (LB * G)
    ngust = lambda V_kt, Ue: 1 + Kg * a * Ue * V_kt / (498.0 * ws_psf)
    UeB, UeC, UeD = gust_velocities(h)
    VC = V_tas * math.sqrt(rho / RHO0) / KT
    VD = 1.25 * VC
    stall = lambda V_kt: RHO0 * (V_kt * KT) ** 2 * p.CLmax_clean / (2 * W / S)
    lo, hi = 1.0, VC                               # V_B: stall line = gust line
    if stall(hi) < ngust(hi, UeB):
        VB = VC
    else:
        for _ in range(40):
            mid = 0.5 * (lo + hi)
            if stall(mid) < ngust(mid, UeB):
                lo = mid
            else:
                hi = mid
        VB = hi
    n_g = max(ngust(VB, UeB), ngust(VC, UeC), ngust(VD, UeD))
    n_ult = p.n_ult if p.n_ult > 0 else 1.5 * max(n_man, n_g)
    return n_man, n_g, n_ult


def wing_mass_raymer(p, W, S, AR, n_ult):
    """Raymer (2006) Eq. 15.25 as given in Metabook Eq. 7.11 (unswept),
    times the composite fudge factor of Metabook Table 7.5."""
    Wdg = W / G / LB
    Sw = S / FT ** 2
    Wlb = (0.0051 * (Wdg * n_ult) ** 0.557 * Sw ** 0.649 * AR ** 0.5 * p.t_c ** -0.4
           * (1 + p.taper) ** 0.1 * (p.f_csw * Sw) ** 0.1)
    return Wlb * LB * p.k_wing_comp


def wing_mass(p, W, S, AR, y_boom, n_ult=None):
    """[v10] wing mass = skins/ribs (area) + spar caps sized for the larger of
    (a) the manoeuvre root bending moment n_ult*W*b/(3*pi) (elliptic load) and
    (b) the rotor/boom load n_hover_ult*(W/2)*y_boom (rotors lift through the
        wing in hover, hard landing on the booms),
    spar depth 0.9*(t/c)*c_root; caps taper to zero at the tip."""
    n_ult = n_ult if n_ult else (p.n_ult if p.n_ult > 0 else 5.7)
    if p.wing_model == "areal":
        return (p.rho_wing * (AR / 9) ** 0.6 + p.m_flap_sys) * S, 0.0, 0.0
    b = math.sqrt(AR * S)
    c_r = 2 * S / (b * (1 + p.taper))
    hsp = 0.9 * p.t_c * c_r
    M_man = n_ult * W * b / (3 * math.pi)
    M_hov = p.n_hover_ult * (W / 2) * y_boom
    M = max(M_man, M_hov)
    m_caps = p.k_web * p.rho_cap * M * b / (p.sigma_cap * hsp)
    m = p.rho_skin * S + m_caps + p.m_flap_sys * S
    if p.wing_model_check:                         # [v18] Metabook Eq. 7.11 floor
        m = max(m, wing_mass_raymer(p, W, S, AR, n_ult))
    return m, M_man, M_hov


def eta_bus(p):
    return p.eta_cable * p.eta_inverter * p.eta_motor


def eta_batt_shaft(p):
    return p.eta_batt * eta_bus(p)


def eta_batt_thr(p):
    return eta_batt_shaft(p) * p.eta_prop


def eta_fuel_thr(p):
    return eta_fuel_shaft(p) * p.eta_prop


def eta_fuel_shaft(p):
    return 1.0 / (p.sfc * LB / (HP * 3600.0) * LHV) * p.eta_generator * eta_bus(p)


def lapse(p, h):
    return (isa_rho(h) / RHO0) ** p.n_lapse


# =============================================================================
#  propulsor models
# =============================================================================
def pusher_thrust(P, V, A, p, rho):
    if P <= 0:
        return 0.0
    T = (p.FM * P) ** (2 / 3) * (2 * rho * A) ** (1 / 3)
    for _ in range(12):
        s = math.sqrt(V * V / 4 + T / (2 * rho * A))
        T -= (T * (V / 2 + s) - p.FM * P) / (V / 2 + s + T / (4 * rho * A * s))
    return min(T, p.eta_prop * P / V) if V > 1.0 else T


def rotor_power(T, th, u, w, ac, p):
    """Shaft power of all lift rotors, thrust T tilted forward by th [rad],
    aircraft velocity (u forward, w up). Glauert inflow by fixed point,
    profile power from the hover FM, variable-rpm scaling (Leishman)."""
    if T <= 1.0:
        return 0.0
    A, W, rho = ac["A_rot"], ac["W"], ac["rho"]
    Vc = u * math.sin(th) + w * math.cos(th)          # through the disk
    Ve = abs(u * math.cos(th) - w * math.sin(th))     # edgewise
    vh = math.sqrt(T / (2 * rho * A))
    vi = vh
    for _ in range(10):
        vi = 0.5 * vi + 0.5 * T / (2 * rho * A * math.sqrt(Ve * Ve + (Vc + vi) ** 2))
    vhW = math.sqrt(W / (2 * rho * A))
    P0 = W * vhW * (1 / p.FM - p.kappa) * (T / W) ** 1.5
    mu = min(Ve / max(p.tip_speed * math.sqrt(T / W), 1.0), 0.5)
    return p.kappa * T * vi + T * Vc + P0 * (1 + 4.65 * mu * mu)


def pusher_power_roc(ac, p, W):
    """Pusher shaft power for the RFP initial climb (1500 fpm, SL ISA+18,
    clean, wing-borne) using the same propeller model as the checks."""
    rho, S, A = isa_rho(0.0), ac["S"], ac["A_push"]
    best = 1e12
    for V in np.linspace(40, 110, 15):
        q = 0.5 * rho * V * V
        CL = W / (q * S)
        if CL > p.CLmax_clean / 1.2 ** 2:
            continue
        T = q * S * (ac["CD0"] + ac["K"] * CL * CL) + W * REQ.roc_min / V
        P_eta = T * V / p.eta_prop
        P_mom = T * (V / 2 + math.sqrt(V * V / 4 + T / (2 * rho * A))) / p.FM
        best = min(best, max(P_eta, P_mom))
    return best


def pusher_power_grad(ac, p, W, grad):
    """Pusher shaft power for a given climb gradient (clean, SL hot, best speed)."""
    rho, S, A = isa_rho(0.0), ac["S"], ac["A_push"]
    best = 1e12
    for V in np.linspace(40, 110, 15):
        q = 0.5 * rho * V * V
        CL = W / (q * S)
        if CL > p.CLmax_clean / 1.2 ** 2:
            continue
        T = q * S * (ac["CD0"] + ac["K"] * CL * CL) + W * grad
        best = min(best, max(T * V / p.eta_prop,
                             T * (V / 2 + math.sqrt(V * V / 4 + T / (2 * rho * A))) / p.FM))
    return best


def climb_polar(ac, p, cfg, gear):
    """[v18] (CD0, K, CL limit) for 'clean', 'TO' or 'LDG' configuration,
    Metabook Table 4.2 and Sec. 4.7.2 (CL = CLmax - 0.2)."""
    if cfg == "clean":
        return ac["CD0"], ac["K"], p.CLmax_clean - p.dCL_climb
    pc = p_takeoff(p) if cfg == "TO" else p
    return (ac["CD0"] + dCD0hl(pc, gear), 1 / (math.pi * ac["AR"] * pc.e_highlift),
            CLhl(pc) - p.dCL_climb)


def pusher_power_cfg(ac, p, W, grad, cfg, gear, rho=None):
    """[v18] pusher shaft power for a climb gradient in a configuration."""
    rho = isa_rho(0.0) if rho is None else rho
    CD0, K, CLl = climb_polar(ac, p, cfg, gear)
    S, A = ac["S"], ac["A_push"]
    best = 1e12
    for V in np.linspace(25, 110, 35):
        q = 0.5 * rho * V * V
        CL = W / (q * S)
        if CL > CLl:
            continue
        T = q * S * (CD0 + K * CL * CL) + W * grad
        best = min(best, max(T * V / p.eta_prop,
                             T * (V / 2 + math.sqrt(V * V / 4 + T / (2 * rho * A))) / p.FM))
    return best


def climb_gradient(ac, p, W, P_shaft, cfg, gear, rho=None):
    """[v18] best steady climb gradient (T - D)/W and rate of climb."""
    rho = isa_rho(0.0) if rho is None else rho
    CD0, K, CLl = climb_polar(ac, p, cfg, gear)
    S = ac["S"]
    g_best, roc_best = -1e9, -1e9
    for V in np.linspace(25, 140, 47):
        q = 0.5 * rho * V * V
        CL = W / (q * S)
        if CL > CLl:
            continue
        D = q * S * (CD0 + K * CL * CL)
        T = pusher_thrust(P_shaft, V, ac["A_push"], p, rho)
        g_best = max(g_best, (T - D) / W)
        roc_best = max(roc_best, (T - D) * V / W)
    return g_best, roc_best


def hover_power(W, A, rho, p):
    return W * math.sqrt(W / (2 * rho * A)) / p.FM


# =============================================================================
#  geometry and drag
# =============================================================================
def geometry(p, w0, ws, AR, D_rot, n_rot=4, h_field=0.0):
    W = w0 * G
    S = W / ws
    b = math.sqrt(AR * S); c = S / b
    L_fus = 0.169 * w0 ** 0.51
    d_eq = math.sqrt(1.6 * 1.8); fr = L_fus / d_eq
    sw_fus = math.pi * d_eq * L_fus * (1 - 2 / fr) ** (2 / 3) * (1 + 1 / fr ** 2)
    l_t = 0.5 * L_fus
    S_ht, S_vt = 0.9 * c * S / l_t, 0.08 * b * S / l_t
    y_boom = 0.8 + D_rot / 2 + 0.3                 # [v10] rotors clear the fuselage
    l_boom = D_rot + 0.6 + c                        # fore and aft rotor + chord
    # Approximate controlling dimension and lift-propulsion rotor diameter for FAA EB 105A.
    # Detailed design must include gear/touchpoint and all protuberances in the controlling circle.
    ctrl_dim = max(b, L_fus)
    rotor_envelope_r = math.hypot(y_boom, 0.5 * l_boom) + 0.5 * D_rot
    rd_vtol = 2.0 * rotor_envelope_r
    kD = (D_rot / 4.0) ** 2                         # blade area ~ D^2
    sw = sw_fus + (S - c * 1.6) * 2.05 + (S_ht + S_vt) * 2.03 + 2 * math.pi * 0.3 * l_boom
    CD0 = (p.Cf * p.k_misc * sw + n_rot * p.f_rot_stop * kD) / S
    K = 1 / (math.pi * AR * p.e_clean)
    return dict(W=W, w0=w0, S=S, b=b, c=c, AR=AR, CD0=CD0, K=K, n_rot=n_rot,
                D_rot=D_rot, A_rot=n_rot * math.pi * D_rot ** 2 / 4,
                A_push=math.pi * p.D_push ** 2 / 4, rho=isa_rho(h_field),
                LDmax=0.5 / math.sqrt(CD0 * K), L_fus=L_fus, y_boom=y_boom,
                l_boom=l_boom, ctrl_dim=ctrl_dim, RD_vtol=rd_vtol, kD=kD,
                S_ht=S_ht, S_vt=S_vt, l_t=l_t)


def LD(ac, W, V, h):
    q = 0.5 * isa_rho(h) * V * V
    CL = W / (q * ac["S"])
    return CL / (ac["CD0"] + ac["K"] * CL * CL), CL


# =============================================================================
#  TAKE-OFF: all 5 propulsors, tilted lift rotors, exact 50 ft / 300 ft
# =============================================================================
def takeoff_sim(ac, p, w_to, theta_max, w_after, dt=0.05, record=False,
                t_fail=None, action=None):
    """Point-mass take-off simulation (x forward, h up).
    to_mode "hover": vertical lift-off, hold h_low until V_rot, then climb.
    to_mode "roll":  ground roll on the wheels with the pusher (rotors carry
                     f_unload*W, tilted theta_ground) until V_lof, then climb.
    Climb: w_to up to the obstacle (bisected to clear 50 ft at 300 ft),
    w_after afterwards, rotors tilted up to theta_max, wing at max usable CL.
    t_fail: time of a lift-rotor failure; after t_recog the aircraft either
    'continue's (rotors vertical, capped at the one-rotor-out capability) or
    'reject's (rotors at capability, pusher in reverse, land and brake).
    action None = choose automatically with failure_outcome()."""
    p = p_takeoff(p)                                   # [v18] take-off setting
    W, S, rho = ac["W"], ac["S"], ac["rho"]
    m = W / G
    CL_tr = p.k_CL_trans * CLhl(p)
    CD0 = ac["CD0"] + dCD0hl(p, gear=False) + ac["n_rot"] * (p.f_rot_spin - p.f_rot_stop) * ac.get("kD", 1.0) / S
    Khl = 1 / (math.pi * ac["AR"] * p.e_highlift)
    V_end = 1.25 * math.sqrt(2 * W / (rho * S * p.CLmax_clean))
    Pr_max, Pp = ac["P_lift"], ac["P_push"]
    thm = math.radians(theta_max)
    x = h = u = w = t = E = peak = 0.0
    h_obs = None
    airborne = p.to_mode in ("hover", "vtol")
    vert_phase = p.to_mode == "vtol"
    failed, decided = False, None
    stop_reason = "end"
    keys = ("t", "x", "h", "u", "w", "ax", "az", "L", "Tv", "Th", "Tp", "Pr", "Pp", "th")
    hist = {k: [] for k in keys}
    while t < 180.0:
        q = 0.5 * rho * u * u
        # ---------------- failure logic
        if t_fail is not None and t >= t_fail:
            failed = True
            if decided is None and t >= t_fail + p.t_recog:
                decided = action or ("continue" if failure_outcome(
                    ac, p, x, h, u, w, "rotor") == "continue" else "reject")
        if failed and decided is None:                     # recognition phase:
            Fz_cmd = None                                  # commands frozen
        # ---------------- vertical guidance
        if decided == "reject":
            w_tgt = -min(p.w_td_emerg * 0.8, max(h, 0.3))
        elif decided == "continue":
            w_tgt = w_to if h < REQ.h_obs + 1 else w_after
        elif not airborne:
            w_tgt = 0.0
        elif vert_phase:
            w_tgt = p.vz_vtol
            if h >= p.h_vtol:
                vert_phase = False
                w_tgt = 0.0
        elif p.to_mode == "vtol" and u < p.V_accel_climb:
            w_tgt = (p.h_vtol - h) / 1.0                  # accelerate level
        elif p.to_mode == "hover" and u < p.V_rot:
            w_tgt = (p.h_low - h) / 0.5
        else:
            w_tgt = w_to if h < REQ.h_obs + 1.0 else w_after
        tau = 0.8 if h < REQ.h_obs + 1.0 else 3.0
        az_c = max(min((w_tgt - w) / tau, 3.0 if h < REQ.h_obs + 1.0 else 1.0), -3.0)
        # ---------------- forces
        on_ground = h <= 0.0 and not airborne
        if on_ground or (decided == "reject" and h <= 0.0):
            CL = min(0.8, CL_tr); L = q * S * CL             # ground attitude
        else:
            Fz = W + m * az_c
            CL = min(CL_tr, Fz / (q * S)) if q > 1.0 else 0.0
            L = q * S * CL
        if on_ground and not failed:
            Tv = p.f_unload * W
            th = math.radians(p.theta_ground) if Tv > 0 else 0.0
        elif decided == "reject" and h <= 0.0:
            Tv, th = 0.0, 0.0
        else:
            Tv = max(W + m * az_c - L, 0.0)
            if u < 12.0 and Tv > 0:
                Tv *= p.k_download
            th = thm if (h > 0.3 and not failed and not vert_phase) else 0.0
        if failed:                                        # capability limit
            cap = (vertical_capability(ac, p, u, w, "rotor")[1] if decided
                   else Pr_max * 0.0 + (Tv * (ac["n_rot"] - 1) / ac["n_rot"]))
            Tv = min(Tv, cap); th = 0.0
            T = Tv
            Pr = rotor_power(T, 0.0, u, w, ac, p) if T > 0 else 0.0   # remaining rotors
        elif Tv > 0:
            T = Tv / math.cos(th)
            Pr = rotor_power(T, th, u, w, ac, p)
            if Pr > Pr_max:
                lo, hi = 0.0, th
                for _ in range(8):
                    mid = 0.5 * (lo + hi)
                    if rotor_power(Tv / math.cos(mid), mid, u, w, ac, p) > Pr_max:
                        hi = mid
                    else:
                        lo = mid
                th = lo; T = Tv / math.cos(th)
                Pr = rotor_power(T, th, u, w, ac, p)
                if Pr > Pr_max:
                    lo, hi = 0.0, T
                    for _ in range(12):
                        mid = 0.5 * (lo + hi)
                        if rotor_power(mid, 0.0, u, w, ac, p) > Pr_max:
                            hi = mid
                        else:
                            lo = mid
                    T, th = lo, 0.0
                    Pr = rotor_power(T, 0.0, u, w, ac, p)
        else:
            T = Pr = 0.0
        Th, Tvert = T * math.sin(th), T * math.cos(th)
        if decided == "reject":
            Tp = -p.f_rev_push * pusher_thrust(Pp, 0.0, ac["A_push"], p, rho) if u > 0.5 else 0.0
            Pp_use = 0.3 * Pp if u > 0.5 else 0.0
        else:
            if vert_phase:                                # pusher idle in the hover climb
                Tp, Pp_use = 0.0, 0.0
            else:
                Tp = pusher_thrust(Pp, u, ac["A_push"], p, rho); Pp_use = Pp
        spin = T > 0
        D = q * S * (CD0 - (0 if spin else ac["n_rot"] * (p.f_rot_spin - p.f_rot_stop) * ac.get("kD", 1.0) / S)
                     + Khl * CL * CL
                     + (p.dCD0_gear if h < REQ.h_obs else 0.0))   # [v18] gear up above 50 ft
        Fric = 0.0
        if h <= 0.0 and (on_ground or decided == "reject"):
            mu = p.mu_brake if decided == "reject" else p.mu_roll
            Fric = mu * max(W - L - Tvert, 0.0)
        ax = (Tp + Th - D - Fric) / m
        if h <= 0.0 and decided == "reject" and u <= 0.3:
            ax = 0.0; u = 0.0
        azr = (Tvert + L - W) / m
        if h <= 0.0 and azr < 0:
            azr = 0.0
        if not airborne and u >= p.V_lof:                 # rotation / lift-off
            airborne = True
        if not airborne:
            azr = min(azr, 0.0)
        Pbus = (Pr + Pp_use) / eta_bus(p)
        if record:
            for k, v in zip(keys, (t, x, h, u, w, ax, azr, L, Tvert, Th, Tp, Pr, Pp_use,
                                   math.degrees(th))):
                hist[k].append(v)
        x_old, h_old = x, h
        u = max(u + ax * dt, 0.0); w += azr * dt
        x += u * dt; h = max(h + w * dt, 0.0)
        if h == 0.0:
            w_td = w
            w = max(w, 0.0)
        E += Pbus * dt; peak = max(peak, Pbus); t += dt
        if h_obs is None and x >= REQ.s_field:
            h_obs = h_old + (h - h_old) * (REQ.s_field - x_old) / max(x - x_old, 1e-9)
        if decided == "reject" and h <= 0.0 and u <= 0.3:
            stop_reason = "stopped"; break
        if T == 0.0 and u >= V_end and not decided == "reject" and airborne:
            break
    E_eq = E - W * h / (p.eta_prop * eta_bus(p))
    out = dict(E=E, E_eq=E_eq, h_obs=h_obs if h_obs is not None else h, t=t, x=x,
               h_end=h, V_end=V_end, peak=peak, ok_end=u >= V_end, decided=decided,
               stop=stop_reason)
    if record:
        out["hist"] = {k: np.array(v) for k, v in hist.items()}
    return out


def takeoff(ac, p, theta_max=None, w_after=None, record=False, t_fail=None, action=None):
    """Smallest initial climb rate that clears 50 ft at exactly 300 ft."""
    th = p.theta_max if theta_max is None else theta_max
    wa = p.w_after_obs if w_after is None else w_after
    if p.to_mode == "vtol":                             # no obstacle bisection
        r = takeoff_sim(ac, p, 0.0, th, wa, record=record, t_fail=t_fail, action=action)
        r.update(cleared=r["h_obs"] >= REQ.h_obs, w_to=None, theta_max=th, w_after=wa)
        return r
    lo, hi = 0.2, 12.0
    r_hi = takeoff_sim(ac, p, hi, th, wa)
    if r_hi["h_obs"] < REQ.h_obs:
        r_hi["cleared"] = False
        return r_hi
    for _ in range(9):
        mid = 0.5 * (lo + hi)
        if takeoff_sim(ac, p, mid, th, wa)["h_obs"] >= REQ.h_obs:
            hi = mid
        else:
            lo = mid
    r = takeoff_sim(ac, p, hi, th, wa, record=record, t_fail=t_fail, action=action)
    r.update(cleared=True, w_to=hi, theta_max=th, w_after=wa)
    return r


def optimise_takeoff(ac, p, thetas=(0, 10, 20, 30), w_afters=(0.0, 2.0, 4.0, 6.0, 7.5)):
    best, table = None, []
    for th in thetas:
        for wa in w_afters:
            r = takeoff(ac, p, th, wa)
            if r.get("cleared") and r["ok_end"]:
                table.append((th, wa, r["E_eq"]))
                if best is None or r["E_eq"] < best["E_eq"]:
                    best = r
    return best, table


# =============================================================================
#  LANDING: glide approach, rotor-supported deceleration, short touchdown
# =============================================================================
def landing(ac, p, dt=0.1, theta_back=None):
    """Glide approach (no power) to the decision point, then level
    deceleration: wing at max usable CL, rotors carry the rest and are tilted
    AFT by theta_back so they also brake; pusher idle; then a short vertical
    touchdown. Rotor power is floored at zero (no regeneration credited)."""
    thb = math.radians(p.theta_max if theta_back is None else theta_back)
    W, S, rho = ac["W"], ac["S"], ac["rho"]
    m = W / G
    CL_tr = p.k_CL_trans * CLhl(p)
    CD0 = ac["CD0"] + dCD0hl(p) + ac["n_rot"] * (p.f_rot_spin - p.f_rot_stop) * ac.get("kD", 1.0) / S
    Khl = 1 / (math.pi * ac["AR"] * p.e_highlift)
    u = 1.25 * math.sqrt(2 * W / (rho * S * p.CLmax_clean))
    E = t = 0.0
    hist = {"t": [], "h": [], "u": [], "w": []}
    while u > 3.0 and t < 200:                        # level deceleration
        for k, v in zip(hist, (t, p.h_trans, u, 0.0)):
            hist[k].append(v)
        q = 0.5 * rho * u * u
        CL = min(CL_tr, W / (q * S)); L = q * S * CL
        Tv = W - L
        if Tv > 1:
            T = Tv / math.cos(thb)
            Pr = max(rotor_power(T, -thb, u, 0.0, ac, p), 0.0)
            Tb = T * math.sin(thb)                       # braking component
        else:
            Pr, Tb = 0.0, 0.0
        D = q * S * (CD0 + Khl * CL * CL)
        u -= (D + Tb) / m * dt; E += Pr / eta_bus(p) * dt; t += dt
    P_desc = hover_power(p.k_download * W, ac["A_rot"], rho, p) * 0.9  # descent helps
    E += P_desc / eta_bus(p) * p.h_trans / p.Vz_down
    for hh in np.linspace(p.h_trans, 0.0, 11):        # vertical descent
        for k, v in zip(hist, (t, hh, 0.0, -p.Vz_down)):
            hist[k].append(v)
        t += p.h_trans / p.Vz_down / 10
    return dict(E=E, t=t, hist={k: np.array(v) for k, v in hist.items()})



def landing_distance_fixed_gamma(ac, p, gamma_deg=18.0):
    """Landing distance from the 50-ft obstacle at a fixed approach angle.
    Used as a transparent 5000-ft / special-use heliport sensitivity, not a certification claim."""
    V = p.V_app
    rho = ac["rho"]
    m = ac["W"] / G
    Tp0 = pusher_thrust(ac["P_push"], 0.0, ac["A_push"], p, rho)
    a_b = p.mu_brake * G + p.f_rev_push * Tp0 / m
    s_ground = 0.5 * V + V * V / (2 * a_b)
    s_air = REQ.h_obs / math.tan(math.radians(gamma_deg))
    return s_air + s_ground + 5.0, s_air, s_ground

def field_case(r, p, h_field_ft):
    """Re-evaluate take-off / landing performance at a field altitude while
    retaining the installed propulsion system of the sized aircraft."""
    h = h_field_ft * FT
    acf = geometry(p, r["mtow"], r["ws"], r["AR"], r["D_rot"], h_field=h)
    acf.update(P_lift=r["P_lift"], P_push=r["P_push"])
    to = takeoff(acf, p, record=True)
    x50 = x_at_height(to["hist"], REQ.h_obs) if to.get("hist") else None
    ld = landing_sim(acf, p)
    l18, lair18, lground18 = landing_distance_fixed_gamma(acf, p, p.heli_approach_deg)
    return dict(ac=acf, to=to, x50=x50, landing=ld, landing_18=l18, landing_air_18=lair18, landing_ground=lground18)

def landing_rolling(ac, p, dt=0.1):
    """Decelerate (rotors tilted aft) at h_obs + 5 m down to V_app, then a
    steep powered approach over the obstacle at constant V_app, touchdown
    with <= 3 m/s sink, free roll 0.5 s, wheel brakes + pusher reverse.
    The descent angle is chosen so the landing fits exactly into 300 ft."""
    thb = math.radians(p.theta_max)
    W, S, rho = ac["W"], ac["S"], ac["rho"]
    m = W / G
    CL_tr = p.k_CL_trans * CLhl(p)
    CD0 = ac["CD0"] + dCD0hl(p) + ac["n_rot"] * (p.f_rot_spin - p.f_rot_stop) * ac.get("kD", 1.0) / S
    Khl = 1 / (math.pi * ac["AR"] * p.e_highlift)
    h1 = REQ.h_obs + 5.0
    u = 1.25 * math.sqrt(2 * W / (rho * S * p.CLmax_clean))
    E = t = 0.0
    hist = {"t": [], "h": [], "u": [], "w": []}
    while u > p.V_app and t < 200:
        for k, v in zip(hist, (t, h1, u, 0.0)):
            hist[k].append(v)
        q = 0.5 * rho * u * u
        CL = min(CL_tr, W / (q * S)); L = q * S * CL
        Tv = W - L
        if Tv > 1:
            T = Tv / math.cos(thb)
            Pr = max(rotor_power(T, -thb, u, 0.0, ac, p), 0.0); Tb = T * math.sin(thb)
        else:
            Pr = Tb = 0.0
        u -= (q * S * (CD0 + Khl * CL * CL) + Tb) / m * dt
        E += Pr / eta_bus(p) * dt; t += dt
    V = p.V_app
    Tp0 = pusher_thrust(ac["P_push"], 0.0, ac["A_push"], p, rho)
    a_b = p.mu_brake * G + p.f_rev_push * Tp0 / m
    s_ground = 0.5 * V + V * V / (2 * a_b)
    s_air = REQ.s_field - s_ground - 5.0
    if s_air <= 5.0:
        return dict(E=E, t=t, s=math.inf, gamma=90.0, hist={k: np.array(v) for k, v in hist.items()})
    gam = math.atan(REQ.h_obs / s_air)
    w = -V * math.sin(gam)
    q = 0.5 * rho * V * V
    L = q * S * CL_tr
    Pr = max(rotor_power(max(W - L, 0.0), 0.0, V, w, ac, p), 0.0)
    t_air = s_air / (V * math.cos(gam))
    E += Pr / eta_bus(p) * t_air
    for hh in np.linspace(REQ.h_obs, 0.0, 11):
        for k, v in zip(hist, (t, hh, V, w)):
            hist[k].append(v)
        t += t_air / 10
    return dict(E=E, t=t, s=s_air + s_ground, gamma=math.degrees(gam),
                hist={k: np.array(v) for k, v in hist.items()})


def poweroff_landing_distance(ac, p):
    """Info: landing on the wing alone (no rotors, no engine) over 50 ft."""
    W, S, rho = ac["W"], ac["S"], ac["rho"]
    CLmax = CLhl(p)
    Vs = math.sqrt(2 * W / (rho * S * CLmax))
    Va = 1.3 * Vs
    CL = CLmax / 1.69
    CD = ac["CD0"] + dCD0hl(p) + CL * CL / (math.pi * ac["AR"] * p.e_highlift)
    gam = math.atan(CD / CL)
    R = Va ** 2 / (0.2 * G)
    s_air = REQ.h_obs / math.tan(gam) + R * gam / 2
    V_td = 1.15 * Vs
    s_gr = V_td * 1.0 + V_td ** 2 / (2 * 0.45 * G)
    return s_air + s_gr, Vs, math.degrees(gam)


# =============================================================================
#  SIZING
# =============================================================================
def size(p, ws, AR, h_cr, D_rot=4.0, w0=5500.0, iters=150, outer=2, to_law=None, fast=False):
    v = max(p.v_cruise, REQ.v_cruise)
    m_pay = REQ.n_occupants * REQ.mass_person
    P_gen = 8e5
    to = la = None
    for _o in range(outer):
        for _ in range(iters):
            ac = geometry(p, w0, ws, AR, D_rot)
            W = ac["W"]
            ld_cr, CL_cr = LD(ac, 0.97 * W, v, h_cr)
            if CL_cr > p.CL_cruise_max:
                return None
            ld_cl, _ = LD(ac, W, p.v_climb, h_cr / 2)
            # installed lift power: hover (with download) at SL and 5000 ft, hot day
            A = ac["A_rot"]
            P_lift = max(hover_power(p.k_download * W, A, isa_rho(0.0), p),
                         hover_power(p.k_download * W, A, isa_rho(REQ.h_field_high), p)
                         * p.k_vtol_margin)
            P_push = max(W * (p.v_climb / ld_cl + REQ.roc_min) / p.eta_prop,
                         0.97 * W * v / ld_cr / p.eta_prop / p.f_cruise_rating,   # Eq. 4.41
                         pusher_power_roc(ac, p, W) * 1.01,
                         pusher_power_cfg(ac, p, W, REQ.grad_min, "TO", True) * 1.01,   # 23.2120a
                         pusher_power_cfg(ac, p, W, 0.03, "LDG", True) * 1.01)          # 23.2120c
            if p.push_lanes > 1:                         # 23.2120b: one lane, 1 %, TO flaps, gear up
                P_lane_req = pusher_power_cfg(ac, p, W, p.grad_oei, "TO", False) / p.k_em_push
                P_push = max(P_push, p.push_lanes * P_lane_req * 1.01)
            ac.update(P_lift=P_lift, P_push=P_push)
            # generator: cruise at altitude + recharge of the climb assist
            P_cr_bus = 0.97 * W * v / ld_cr / p.eta_prop / eta_bus(p)
            t_cl = h_cr / REQ.roc_min
            E_cb = max(P_push / eta_bus(p) - P_gen * lapse(p, h_cr / 2), 0.0) * t_cl
            # [v12] systems: cruise, climb (mean altitude), descent, ground
            P_aux_cr = aux_power(p, h_cr, P_cr_bus * eta_bus(p))[0]
            P_aux_cl = aux_power(p, h_cr / 2, P_push)[0]
            P_aux_de = aux_power(p, h_cr / 2, 0.0)[0]
            P_aux_gr = aux_power(p, 0.0, P_lift)[0]
            P_gen = 0.5 * P_gen + 0.5 * (P_cr_bus + P_aux_cr + E_cb / (p.eta_batt * 1800.0)) / lapse(p, h_cr) \
                / p.f_cruise_rating                      # [v18] Eq. 4.41
            if fast:                                     # [v10] surrogate
                to = dict(E=p.k_to_E * P_lift, peak=(P_lift + P_push) / eta_bus(p) * 1.05,
                          h_obs=REQ.h_obs, t=35.0, cleared=True)
                la = dict(E=p.k_la_E * P_lift, s=REQ.s_field * 0.97, gamma=18.0)
            if to is None:                               # first guess
                to = dict(E=30 * P_lift / eta_bus(p), peak=(P_lift + P_push) / eta_bus(p))
                la = dict(E=20 * P_lift / eta_bus(p))
            # masses
            P_el = (P_lift + P_push) / 1e3
            k_lift = 1.0 + p.k_lane_mass * (p.lift_lanes - 1)
            k_push = p.k_push_combiner if p.push_lanes > 1 else 1.0
            m_mot = ((k_lift * P_lift + k_push * P_push) / 1e3
                     * (1 / p.sp_motor + 1 / p.sp_inverter))
            m_rot = 4 * (p.m_boom * (ac["l_boom"] / 5.5 - 1.0) * 0.5 + p.m_rotor * (D_rot / 4) ** p.k_rotor_D + p.m_boom) + p.m_push_prop
            m_gen = P_gen / 1e3 * (1 / p.sp_generator + 1 / (p.sp_turboshaft * p.eta_generator))
            m_cool = p.f_cool * (m_mot + m_gen)
            n_man, n_gust, n_ult = design_load_factor(p, W, ac["S"], AR, v, h_cr)   # [v18]
            m_wing = wing_mass(p, W, ac["S"], AR, ac["y_boom"], n_ult)[0] * p.k_struct
            # empty-weight regression, Raymer twin turboprop (metric: A = 0.92,
            # C = -0.05, Metabook Table 2.1); the -0.23 removes wing and
            # propulsion (booked separately). Own assumption -> bracketed in
            # the report by the Metabook Table 7.1 buildup (Sec. 7.2).
            m_af = (0.92 * w0 ** -0.05 - 0.23) * w0 * p.k_struct * p.k_airframe
            # mission: climb (fuel), fuel cruise, 150 nmi electric, glide descent
            s_cl = p.v_climb * t_cl / NMI
            s_de, t_de, E_de, f_pow = descent_profile(ac, p, 0.9 * W, h_cr)   # [v11]
            r1 = REQ.range_total - s_cl - REQ.range_el_cruise - s_de
            if r1 < 0:
                return None
            fuel_cl = (W * h_cr + W * s_cl * NMI / ld_cl) / eta_fuel_thr(p) / LHV
            eta_fb = eta_fuel_shaft(p) / eta_bus(p)              # fuel -> DC bus
            t_r1 = r1 * NMI / v
            fuel_aux = (P_aux_cl * t_cl + P_aux_cr * t_r1) / eta_fb / LHV
            w = w0 - fuel_cl - fuel_aux
            w *= math.exp(-r1 * NMI * G / (eta_fuel_thr(p) * LHV * ld_cr))
            fuel = w0 - w
            E_el = w * G * REQ.range_el_cruise * NMI / (ld_cr * eta_batt_thr(p))
            t_el = REQ.range_el_cruise * NMI / v
            E_aux_b = (P_aux_cr * t_el + P_aux_de * t_de + P_aux_gr * 600.0) / p.eta_batt
            E_mis = E_el + E_de + (to["E"] + la["E"]) / p.eta_batt + p.e_ground + E_aux_b
            ld_res, _ = LD(ac, w * G, math.sqrt(2 * w * G / (isa_rho(5000 * FT) * ac["S"]
                           * math.sqrt(ac["CD0"] / ac["K"]))), 5000 * FT)
            t_res = REQ.range_el_reserve * NMI / 70.0
            E_res = (w * G * REQ.range_el_reserve * NMI / (ld_res * eta_batt_thr(p))
                     + la["E"] / p.eta_batt
                     + aux_power(p, 5000 * FT)[0] * t_res / p.eta_batt)       # [v12]
            m_bE = (E_mis + E_res) / (p.e_pack * p.dod)
            m_bP = max(to["peak"] - p.f_gen_takeoff * P_gen * lapse(p, 0.0), 0.0) / (p.p_pack * 1e3)
            m_bat = max(m_bE, m_bP)
            fuel_res = w * (math.exp((REQ.range_alternate + p.v_hold / KT * REQ.time_hold)
                                     * NMI * G / (eta_fuel_thr(p) * LHV * ac["LDmax"])) - 1)
            fuel_res += aux_power(p, p.h_hold)[0] * (REQ.time_hold * 3600 + REQ.range_alternate
                                                     * NMI / p.v_hold) / eta_fb / LHV
            m_sys = ((p.m_press_struct + p.m_ecs) if p.pressurised else 0.0) + p.m_aux_electric
            parts = dict(payload=m_pay, airframe=m_af, wing=m_wing, systems_extra=m_sys,
                         motors_inverters=m_mot + m_cool, rotors_props=m_rot,
                         genset=m_gen, battery=m_bat, fuel_mission=fuel, fuel_reserve=fuel_res)
            w0_new = sum(parts.values())
            if w0_new > 2e4:
                return None
            if abs(w0_new - w0) < 1.0:
                w0 = w0_new
                break
            w0 += 0.6 * (w0_new - w0)
        else:
            return None
        ac = geometry(p, w0, ws, AR, D_rot)
        ac.update(P_lift=P_lift, P_push=P_push)
        if fast:
            break
        if to_law:
            to = takeoff(ac, p, *to_law)
        else:
            to = takeoff(ac, p)
        if not to.get("cleared"):
            return None
        # Use the time-domain landing model for the actual closure; keep the
        # analytic rolling model available for approach-angle sensitivity.
        la = landing_sim(ac, p) if p.landing_mode == "rolling" else landing(ac, p)
        if la.get("s") is None or not math.isfinite(la.get("s", 0.0)) or la["s"] > REQ.s_field:
            return None
    t_block = (h_cr / REQ.roc_min + r1 * NMI / v + REQ.range_el_cruise * NMI / v + t_de
               + to["t"] + 120.0) / 3600 + p.t_taxi
    r = dict(ac=ac, parts=parts, mtow=w0, ws=ws, AR=AR, h_cr=h_cr, D_rot=D_rot, v=v,
             t_block=t_block,
             ld_cr=ld_cr, CL_cr=CL_cr, P_lift=P_lift, P_push=P_push, P_gen=P_gen,
             n_man=n_man, n_gust=n_gust, n_ult=n_ult,
             m_bE=m_bE, m_bP=m_bP, E_el=E_el, E_mis=E_mis, E_res=E_res, fuel=fuel,
             fuel_res=fuel_res, s_cl=s_cl, s_de=s_de, t_de=t_de, E_de=E_de, f_pow_de=f_pow,
             P_aux=dict(cruise=P_aux_cr, climb=P_aux_cl, descent=P_aux_de, ground=P_aux_gr),
             E_aux_batt=E_aux_b, fuel_aux=fuel_aux,
             r1=r1, to=to, la=la,
             E_prim=fuel * LHV + E_mis / 0.95)
    r["cost"] = cost(p, r)
    r["checks"] = checks(p, r)
    r["ok"] = all(v >= 0 for v in r["checks"].values())
    return r


def checks(p, r):
    ac = r["ac"]
    W, S = ac["W"], ac["S"]
    rho = isa_rho(0.0)
    best_roc, best_grad = -1e9, -1e9
    for V in np.linspace(35, 110, 16):                  # wing-borne, clean, SL hot
        q = 0.5 * rho * V * V
        CL = W / (q * S)
        if CL > p.CLmax_clean / 1.2 ** 2:
            continue
        D = q * S * (ac["CD0"] + ac["K"] * CL * CL)
        T = pusher_thrust(r["P_push"], V, ac["A_push"], p, rho)
        best_roc = max(best_roc, (T - D) * V / W)
        best_grad = max(best_grad, (T - D) / W)
    # [v18] FAR 23.2120 (Level 3 low-speed) as listed in Metabook Sec. 4.7.2
    P_lane = r["P_push"] / p.push_lanes * p.k_em_push if p.push_lanes > 1 else 0.0
    g_a = climb_gradient(ac, p, W, r["P_push"], "TO", True)[0]    # AEO, TO flaps, gear down
    g_b = climb_gradient(ac, p, W, P_lane, "TO", False)[0]        # OEI, TO flaps, gear up
    g_c = climb_gradient(ac, p, W, r["P_push"], "LDG", True)[0]   # AEO balked landing, W_L = W_TO
    # [v18] service ceiling at the cruise altitude (Sec. 4.8), clean, MTOW
    roc_ceil = climb_gradient(ac, p, W, r["P_push"], "clean", False, rho=isa_rho(r["h_cr"]))[1]
    r["climb_FAR23"] = dict(a=g_a, b=g_b, c=g_c, roc_ceiling=roc_ceil)
    hp = heliport_eval(r, p, 0.0)
    return dict(MTOW=1 - r["mtow"] / REQ.mtow_max,
                FAR23_2120a=g_a / REQ.grad_min - 1,
                FAR23_2120b=g_b / p.grad_oei - 1,
                FAR23_2120c=g_c / 0.03 - 1,
                ceiling_ROC=roc_ceil / p.roc_ceiling - 1,
                ceiling=1 - r["h_cr"] / REQ.h_max,
                obstacle=r["to"]["h_obs"] / REQ.h_obs - 1 + 1e-6,
                landing=1 - r["la"]["s"] / REQ.s_field,
                span=1 - ac["b"] / p.span_max,
                ROC=best_roc / REQ.roc_min - 1,
                battery_C=1 - r["m_bP"] / max(r["m_bE"], 1e-9) + 1e-9,
                heliport_MTOW=1 - r["mtow"] / p.heliport_mtow_max,
                heliport_CD=1 - hp["ctrl_dim"] / p.heliport_cd_max,
                HOGE=hp["hoge_margin"] - 1.0,
                WS_max=1 - r["ws"] / REQ.ws_max)          # [v17b] W/S <= 4200 N/m^2


def cost(p, r):
    E_kWh = r["E_mis"] / 3.6e6
    cap_b = p.c_batt * r["parts"]["battery"] * p.e_pack / 3.6e6
    acq = (cap_b + (p.c_motor + p.c_inverter) * (r["P_lift"] + r["P_push"]) / 1e3
           + p.c_genset * r["P_gen"] / 1e3
           + p.c_airframe * (r["parts"]["airframe"] + r["parts"]["wing"] + r["parts"]["rotors_props"]))
    t_fl = r["t_block"]
    c_fl = (E_kWh * p.c_elec + r["fuel"] * p.c_fuel + cap_b / p.n_cycles
            + (acq - cap_b) / p.life_h * t_fl + p.c_maint * t_fl)
    c_time = p.VOT * 7 * t_fl
    return dict(acq=acq, flight=c_fl, seat_nmi=c_fl / (7 * REQ.range_total),
                generalised=c_fl + c_time, time_cost=c_time)


# =============================================================================
#  [v5] CRITICAL LOSS OF THRUST -- lift rotors
# =============================================================================
def rotor_max_thrust(ac, p, P_shaft, u, w):
    """Largest thrust ONE lift rotor makes with shaft power P_shaft."""
    n = ac["n_rot"]
    a1 = dict(ac, A_rot=ac["A_rot"] / n, W=ac["W"] / n)
    lo, hi = 0.0, 3.0 * a1["W"]
    for _ in range(22):
        mid = 0.5 * (lo + hi)
        if rotor_power(mid, 0.0, u, w, a1, p) > P_shaft:
            hi = mid
        else:
            lo = mid
    return lo


def vertical_capability(ac, p, u, w, mode):
    """Max vertical force [N] after a failure, rotors vertical, all others at
    emergency power. mode 'rotor' = whole rotor lost, 'lane' = one motor lane
    of one rotor lost. Quad layout: roll+pitch balance at low speed forces the
    diagonal partner of the weak rotor down to the same thrust (Mueller &
    D'Andrea 2014 show a quad cannot hold normal attitude on 3 rotors);
    aerodynamic controls release that as speed builds up (V_ctrl)."""
    n = ac["n_rot"]
    P1 = ac["P_lift"] / n * p.k_em_lift
    Tm = rotor_max_thrust(ac, p, P1, u, w)
    if mode == "rotor" or p.lift_lanes == 1:
        Tf = 0.0
    else:
        Tf = rotor_max_thrust(ac, p, P1 * (p.lift_lanes - 1) / p.lift_lanes, u, w)
    f_aero = min(1.0, (u / p.V_ctrl) ** 2)
    T_bal = 2 * Tf + f_aero * (Tm - Tf) + 2 * Tm       # (n = 4 layout)
    q = 0.5 * ac["rho"] * u * u
    L = q * ac["S"] * p.k_CL_trans * CLhl(p)
    return T_bal + L, T_bal


def failure_outcome(ac, p, x, h, u, w, mode, phase="takeoff"):
    """What happens if the failure occurs in state (x, h, u, w)?
    returns 'continue' / 'go-around', 'reject', 'reject-overrun', 'UNSAFE'."""
    W = ac["W"]
    m = W / G
    F, Trot = vertical_capability(ac, p, u, w, mode)
    if F >= W:
        return "continue" if phase == "takeoff" else "land/go-around"
    # recognition: the lost thrust share is missing for t_recog
    n = ac["n_rot"]
    lost = (W - min(q_wing(ac, p, u), W)) / n * (1.0 if mode == "rotor" or p.lift_lanes == 1
                                                 else 1.0 / p.lift_lanes)
    a0 = lost / m
    w1 = w - a0 * p.t_recog
    h1 = h + w * p.t_recog - 0.5 * a0 * p.t_recog ** 2
    if h1 <= 0:
        v_imp = abs(min(w1, 0.0))
        h1 = 0.0
    else:
        a = (W - F) / m                                # net sink acceleration
        v_imp = math.sqrt(max(w1, 0.0) ** 2 * 0 + min(w1, 0.0) ** 2 + 2 * a * h1
                          + max(w1, 0.0) ** 2)
    if v_imp > p.w_td_emerg:
        return "UNSAFE"
    # horizontal: descent time, then brake with pusher reverse + wheels
    a = max((W - F) / m, 1e-3)
    t_d = (max(w1, 0) + math.sqrt(max(w1, 0) ** 2 + 2 * a * h1)) / a if h1 > 0 else 0.0
    Tp0 = pusher_thrust(ac["P_push"], 0.0, ac["A_push"], p, ac["rho"])
    dec = p.f_rev_push * Tp0 / m
    u_td = max(u - dec * (p.t_recog + t_d), 0.0)
    s = x + u * p.t_recog + max(u * t_d - 0.5 * dec * t_d ** 2, 0.0) + \
        u_td ** 2 / (2 * (p.mu_brake * G + dec))
    if phase == "landing":
        return "land/go-around"
    return "reject" if s <= p.L_runway else "reject-overrun"


def q_wing(ac, p, u):
    return 0.5 * ac["rho"] * u * u * ac["S"] * p.k_CL_trans * CLhl(p)


def failure_timeline(ac, p, hist, mode, phase):
    return [failure_outcome(ac, p, (hist["x"][i] if "x" in hist else 0.0), hist["h"][i],
                            hist["u"][i], (hist["w"][i] if "w" in hist else 0.0), mode, phase)
            for i in range(len(hist["t"]))]


def hv_map(ac, p, mode, us=np.linspace(0, 45, 46), hs=np.linspace(0, 40, 41)):
    code = {"continue": 0, "reject": 1, "reject-overrun": 2, "UNSAFE": 3}
    Z = np.zeros((len(hs), len(us)))
    for i, h in enumerate(hs):
        for j, u in enumerate(us):
            Z[i, j] = code[failure_outcome(ac, p, 0.0, h, u, 0.0, mode)]
    return us, hs, Z


def clot_study(p, r, to_rec, fname):
    ac = r["ac"]
    H = to_rec["hist"]
    # vertical speed history from h
    H = dict(H)
    H["w"] = np.gradient(H["h"], H["t"])
    res = {}
    for mode in ("rotor", "lane"):
        if mode == "lane" and p.lift_lanes == 1:
            continue
        tl = failure_timeline(ac, p, H, mode, "takeoff")
        unsafe = [H["t"][i] for i, o in enumerate(tl) if o == "UNSAFE"]
        cont = [i for i, o in enumerate(tl) if o == "continue"]
        i_tdp = next((i for i in range(len(tl)) if all(o == "continue" for o in tl[i:])), None)
        res[mode] = dict(timeline=tl, unsafe=(min(unsafe), max(unsafe)) if unsafe else None,
                         tdp=(H["t"][i_tdp], H["h"][i_tdp], H["u"][i_tdp]) if i_tdp is not None else None)
        la = r["la"]["hist"]
        tl_la = failure_timeline(ac, p, la, mode, "landing")
        # landing: 'UNSAFE' if failure cannot be survived
        res[mode]["landing_unsafe"] = sum(o == "UNSAFE" for o in tl_la) / max(len(tl_la), 1)
    # plot H-V map for rotor failure with the take-off path
    fig, axs = plt.subplots(1, 2 if p.lift_lanes > 1 else 1, figsize=(15 if p.lift_lanes > 1 else 8, 6))
    axs = np.atleast_1d(axs)
    for ax, mode in zip(axs, ("rotor", "lane")):
        us, hs, Z = hv_map(ac, p, mode)
        cm = matplotlib.colors.ListedColormap(["#9be39b", "#9bc4e3", "#e3d89b", "#e39b9b"])
        ax.pcolormesh(us / KT, hs / FT, Z, cmap=cm, vmin=-0.5, vmax=3.5, shading="nearest")
        ax.plot(H["u"] / KT, H["h"] / FT, "k-", lw=2, label="take-off path")
        ax.set_xlim(0, us[-1] / KT); ax.set_ylim(0, hs[-1] / FT)
        ax.set_xlabel("speed [kt]"); ax.set_ylabel("height [ft]")
        ax.set_title(f"Failure of one {'whole lift rotor' if mode == 'rotor' else 'motor lane'}"
                     f" ({p.lift_lanes} lane/rotor, {p.k_em_lift:.1f}x emergency power)")
        handles = [plt.Rectangle((0, 0), 1, 1, fc=c) for c in
                   ("#9be39b", "#9bc4e3", "#e3d89b", "#e39b9b")]
        ax.legend(handles + [plt.Line2D([], [], color="k", lw=2)],
                  ["continue", "reject on runway", "reject, overrun", "AVOID (unsafe)", "take-off path"],
                  loc="upper right", fontsize=8)
    fig.suptitle("Height-velocity diagram for a lift-rotor failure (SL ISA+18)")
    fig.tight_layout(); fig.savefig(fname, dpi=140); plt.close(fig)
    return res


def pusher_lane_study(p, r):
    """One pusher lane lost: take-off, climb, cruise and glide."""
    ac = r["ac"]
    P_lane = r["P_push"] / p.push_lanes
    out = {}
    a_to = dict(ac, P_push=P_lane * p.k_em_push)
    t = takeoff(a_to, p, p.theta_max, p.w_after_obs)
    out["takeoff"] = bool(t.get("cleared")) and bool(t.get("ok_end"))
    # max level speed at cruise altitude on one lane (continuous rating)
    h = r["h_cr"]; rho = isa_rho(h)
    vmax = 0.0
    for V in np.linspace(50, 130, 81):
        q = 0.5 * rho * V * V
        CL = ac["W"] / (q * ac["S"])
        D = q * ac["S"] * (ac["CD0"] + ac["K"] * CL * CL)
        if p.eta_prop * P_lane / V >= D:
            vmax = V
    out["vmax_one_lane_kt"] = vmax / KT
    out["glide_nmi"] = h * ac["LDmax"] / NMI
    return out


# =============================================================================
#  [v7] decision at lift-off and choice of the design take-off law
# =============================================================================
def x_at_height(H, h_target):
    idx = np.argmax(H["h"] >= h_target) if (H["h"] >= h_target).any() else None
    return None if idx is None else H["x"][idx]


def liftoff_decision(ac, p, base):
    """Failure just before lift-off -> reject: stop distance from brake
    release. Failure just after lift-off -> continue: never touches the ground
    again, reaches 50 ft and the wing-borne end state."""
    H = base["hist"]
    i = int(np.argmax(H["h"] > 0.05))
    t_lof, x_lof, v_lof = H["t"][i], H["x"][i], H["u"][i]
    kw = dict(w_to=base["w_to"], theta_max=base["theta_max"], w_after=base["w_after"])
    rj = takeoff_sim(ac, p, kw["w_to"], kw["theta_max"], kw["w_after"], record=True,
                     t_fail=max(t_lof - 0.05, 0.0), action="reject")
    ct = takeoff_sim(ac, p, kw["w_to"], kw["theta_max"], kw["w_after"], record=True,
                     t_fail=t_lof + 0.05, action="continue")
    Hc = ct["hist"]
    after = Hc["t"] > t_lof + 0.5
    touched = bool(after.any() and Hc["h"][after].min() <= 0.01)
    x50 = x_at_height(Hc, REQ.h_obs)
    return dict(t_lof=t_lof, x_lof=x_lof, v_lof=v_lof, x_stop=rj["x"],
                reject_ok=rj["x"] <= REQ.s_field and rj["stop"] == "stopped",
                continue_ok=(not touched) and x50 is not None and ct["ok_end"],
                x50_oei=x50, rj=rj, ct=ct)


def design_takeoff(ac, p, V_list=(15, 18, 21, 24, 27, 30), f_list=(0.3, 0.5, 0.7)):
    """Cheapest ground-roll law that clears 50 ft at 300 ft AND satisfies the
    lift-off decision (reject before / continue after)."""
    best, table = None, []
    for vl in V_list:
        for fu in f_list:
            pp = replace(p, to_mode="roll", V_lof=vl * KT, f_unload=fu)
            r = takeoff(ac, pp, record=True)
            if not (r.get("cleared") and r["ok_end"]):
                table.append((vl, fu, None, None, None)); continue
            d = liftoff_decision(ac, pp, r)
            ok = d["reject_ok"] and d["continue_ok"]
            table.append((vl, fu, r["E_eq"], d["x_stop"], d["x50_oei"] if d["x50_oei"] else None, ok))
            if ok and (best is None or r["E_eq"] < best[0]["E_eq"]):
                best = (r, d, pp)
    return best, table


# =============================================================================
#  [v8] THREE-PHASE TAKE-OFF WITH V1
#   phase 1: vertical lift-off on the lift rotors to h_low (pusher optional)
#   phase 2: pusher full, rotors tilted forward, low acceleration to V_cs,
#            then climb (w_to) over the obstacle while accelerating
#   phase 3: wing-borne (rotors stopped), climb-out
#   failure before V1 -> REJECT: pusher reverse (+ rotors tilted aft if they
#                        are all alive), descend, brake, stop within 300 ft
#   failure after  V1 -> CONTINUE: clear 50 ft at 300 ft and fly away
#   failure types: "rotor" (one lift rotor lost) or "push" (one pusher lane)
# =============================================================================
def takeoff3_sim(ac, p, law, t_fail=None, fmode="rotor", action=None, dt=0.05):
    p = p_takeoff(p)                                   # [v18] idempotent
    h_low, V_cs, w_to, th_deg, push_p1 = law
    W, S, rho = ac["W"], ac["S"], ac["rho"]
    m = W / G
    CL_tr = p.k_CL_trans * CLhl(p)
    CD0 = ac["CD0"] + dCD0hl(p, gear=False) + ac["n_rot"] * (p.f_rot_spin - p.f_rot_stop) * ac.get("kD", 1.0) / S
    Khl = 1 / (math.pi * ac["AR"] * p.e_highlift)
    V_end = 1.25 * math.sqrt(2 * W / (rho * S * p.CLmax_clean))
    Pr_max = ac["P_lift"]
    P_lane = ac["P_push"] / p.push_lanes
    thm = math.radians(th_deg)
    x = h = u = w = t = E = 0.0
    phase, h_obs, w_touch, touched = 1, None, None, False
    keys = ("t", "x", "h", "u", "w", "ax", "az", "L", "Tv", "Th", "Tp", "Pr", "Pp", "th")
    H = {k: [] for k in keys}
    while t < 120:
        failed = t_fail is not None and t >= t_fail
        rej = failed and action == "reject"
        q = 0.5 * rho * u * u
        # ---- guidance
        if rej:
            w_tgt = -min(2.0, max(h / 1.5, 0.5)) if h > 0 else 0.0
        elif phase == 1:
            w_tgt = 1.5
            if h >= h_low:
                phase = 2
        elif u < V_cs:
            w_tgt = (h_low - h) / 0.8
        else:
            w_tgt = w_to if h < REQ.h_obs + 3.0 else 7.5
        az_c = max(min((w_tgt - w) / 0.6, 3.0), -3.0)
        on_ground = h <= 0.0 and (rej or t == 0.0)
        # ---- wing
        if on_ground and rej:
            CL = 0.3
        else:
            CL = min(CL_tr, (W + m * az_c) / (q * S)) if q > 1 else 0.0
        L = q * S * CL
        # ---- rotors
        Tv = max(W + m * az_c - L, 0.0) if not (on_ground and rej) else 0.0
        if u < 12 and Tv > 0:
            Tv *= p.k_download
        if phase == 1 or (failed and fmode in ("rotor", "lane")):
            th = 0.0
        elif rej:                                        # all rotors alive: brake
            th = -thm
        else:
            th = thm
        if failed and fmode in ("rotor", "lane"):
            Tv = min(Tv, vertical_capability(ac, p, u, w, fmode)[1])
            T = Tv
            Pr = rotor_power(T, 0.0, u, w, ac, p) if T > 0 else 0.0
        elif Tv > 0:
            T = Tv / math.cos(th)
            Pr = rotor_power(T, th, u, w, ac, p)
            if Pr > Pr_max:                              # power limit: vertical first
                lo, hi = 0.0, abs(th)
                for _ in range(8):
                    mid = 0.5 * (lo + hi)
                    if rotor_power(Tv / math.cos(mid), math.copysign(mid, th), u, w, ac, p) > Pr_max:
                        hi = mid
                    else:
                        lo = mid
                th = math.copysign(lo, th); T = Tv / math.cos(th)
                Pr = rotor_power(T, th, u, w, ac, p)
                if Pr > Pr_max:
                    lo2, hi2 = 0.0, T
                    for _ in range(12):
                        mid = 0.5 * (lo2 + hi2)
                        if rotor_power(mid, 0.0, u, w, ac, p) > Pr_max:
                            hi2 = mid
                        else:
                            lo2 = mid
                    T, th = lo2, 0.0
                    Pr = rotor_power(T, 0.0, u, w, ac, p)
            Pr = max(Pr, 0.0)
        else:
            T = Pr = 0.0
        Th, Tvert = T * math.sin(th), T * math.cos(th)
        # ---- pusher
        P_avail = (P_lane * p.k_em_push if (failed and fmode == "push")
                   else ac["P_push"])
        if rej:
            Tp = -p.f_rev_push * pusher_thrust(P_avail, 0.0, ac["A_push"], p, rho) if u > 0.3 else 0.0
            Pp = 0.3 * P_avail if u > 0.3 else 0.0
        elif phase == 1 and not push_p1:
            Tp = Pp = 0.0
        else:
            Tp = pusher_thrust(P_avail, u, ac["A_push"], p, rho); Pp = P_avail
        D = q * S * (CD0 - (0 if T > 0 else ac["n_rot"] * (p.f_rot_spin - p.f_rot_stop) * ac.get("kD", 1.0) / S)
                     + Khl * CL * CL
                     + (p.dCD0_gear if h < REQ.h_obs else 0.0))   # [v18] gear up above 50 ft
        Fr = p.mu_brake * max(W - L - Tvert, 0.0) if (h <= 0 and rej and t > 0) else 0.0
        ax = (Tp + Th - D - Fr) / m
        azr = (Tvert + L - W) / m
        if h <= 0 and azr < 0:
            azr = 0.0
        E += (Pr + Pp) / eta_bus(p) * dt
        for k, v in zip(keys, (t, x, h, u, w, ax, azr, L, Tvert, Th, Tp, Pr, Pp, math.degrees(th))):
            H[k].append(v)
        x_old, h_old = x, h
        u = max(u + ax * dt, 0.0); w += azr * dt
        x += u * dt; h += w * dt; t += dt
        if h < 0:
            if t > 0.5:
                touched = True
                w_touch = w if w_touch is None else min(w_touch, w)
            h, w = 0.0, 0.0
        if h_obs is None and x >= REQ.s_field:
            h_obs = h_old + (h - h_old) * (REQ.s_field - x_old) / max(x - x_old, 1e-9)
        if rej and h <= 0 and u <= 0.3:
            break
        if not rej and T == 0 and u >= V_end and h > REQ.h_obs:
            phase = 3
            break
    return dict(H={k: np.array(v) for k, v in H.items()}, E=E, x=x, h_obs=h_obs if h_obs is not None else h,
                touched=touched, w_touch=-(w_touch or 0.0), end=(phase == 3), t=t,
                stopped=rej and u <= 0.3 and h <= 0)


def v1_analysis(ac, p_in, law, dt_f=0.25):
    """Scan the failure time. REJECT ok = stops within 300 ft with a touchdown
    sink <= w_td_emerg; CONTINUE ok = 50 ft at <= 300 ft, no ground contact,
    reaches the wing-borne end state. A single V1 must exist for BOTH
    failure types. Uses the TAKE-OFF flap setting."""
    p = p_takeoff(p_in)
    aeo = takeoff3_sim(ac, p, law)
    if aeo["h_obs"] < REQ.h_obs or not aeo["end"]:
        return dict(ok=False, aeo=aeo, reason="AEO does not clear 50 ft at 300 ft")
    Ha = aeo["H"]
    t_end = Ha["t"][np.argmax(Ha["Tv"] <= 1.0)] if (Ha["Tv"][10:] <= 1.0).any() else Ha["t"][-1]
    rows = []
    for tf in np.arange(0.0, min(t_end, 15.0) + 1e-6, dt_f):
        i = min(int(tf / 0.05), len(Ha["t"]) - 1)
        rec = dict(t=tf, u=Ha["u"][i], h=Ha["h"][i], x=Ha["x"][i])
        lm = lift_fmode(p)
        for fm in (lm, "push"):
            rj = takeoff3_sim(ac, p, law, tf, fm, "reject")
            ct = takeoff3_sim(ac, p, law, tf, fm, "continue")
            rec[fm + "_rej"] = rj["stopped"] and rj["x"] <= REQ.s_field and rj["w_touch"] <= p.w_td_emerg
            rec[fm + "_cont"] = ct["h_obs"] >= REQ.h_obs and ct["end"] and not ct["touched"]
            rec[fm + "_rj"], rec[fm + "_ct"] = rj, ct
        rec["rej"] = rec[lm + "_rej"] and rec["push_rej"]
        rec["cont"] = rec[lm + "_cont"] and rec["push_cont"]
        rows.append(rec)
        # stop once continue has been OK for 2 s beyond 40 kt (wing dominant)
        if (rec["u"] > 40 * KT and len(rows) > 8
                and all(r["cont"] for r in rows[-8:])):
            break
    # V1 = first index k with rej ok for all before and cont ok for all from k
    v1 = None
    for k in range(len(rows) + 1):
        if all(r["rej"] for r in rows[:k]) and all(r["cont"] for r in rows[k:]):
            v1 = k
            break
    return dict(ok=v1 is not None, aeo=aeo, rows=rows, k_v1=v1, lm=lift_fmode(p),
                v1=None if v1 is None or v1 >= len(rows) else rows[v1])


def design_takeoff3(p, best, laws, margins=(1.0, 1.1, 1.2, 1.3, 1.5)):
    """Smallest rotor power margin (-> lowest mass) and cheapest law that
    give a valid V1."""
    for km in margins:
        pk = replace(p, k_vtol_margin=km, v_cruise=best["v"])
        r = size(pk, best["ws"], best["AR"], best["h_cr"], best["D_rot"])
        if r is None:
            continue
        found = []
        for law in laws:
            a = v1_analysis(r["ac"], pk, law)
            if a["ok"]:
                found.append((a["aeo"]["E"], law, a))
        if found:
            E, law, a = min(found, key=lambda f: f[0])
            return km, r, pk, law, a, len(found)
    return None


def plot_v1(a, fname, title):
    rows = a["rows"]
    fig, ax = plt.subplots(1, 2, figsize=(14, 5))
    t = [r["t"] for r in rows]
    lm = a["lm"]
    for fm, c in ((lm, "tab:red"), ("push", "tab:blue")):
        ax[0].step(t, [1.0 if r[fm + "_rej"] else 0.0 for r in rows], where="post", color=c,
                   ls="--", label=f"{fm} failure: reject OK")
        ax[0].step(t, [1.1 if r[fm + "_cont"] else 0.1 for r in rows], where="post", color=c,
                   label=f"{fm} failure: continue OK")
    if a["v1"]:
        ax[0].axvline(a["v1"]["t"], color="k", lw=2)
        ax[0].text(a["v1"]["t"], 0.55, f"  V1 = {a['v1']['u'] / KT:.0f} kt\n  h = {a['v1']['h'] / FT:.0f} ft",
                   fontsize=10)
    ax[0].set_yticks([0.05, 1.05]); ax[0].set_yticklabels(["not OK", "OK"])
    ax[0].set_xlabel("failure time [s]"); ax[0].legend(fontsize=8)
    ax[0].set_title("Reject / continue capability vs failure time")
    H = a["aeo"]["H"]
    ax[1].plot(H["x"] / FT, H["h"] / FT, "k-", lw=2, label="all engines")
    if a["v1"]:
        k = a["k_v1"]
        for idx, ls in ((max(k - 1, 0), "--"), (k, ":")):
            r = rows[idx]
            ax[1].plot(r[lm + "_rj"]["H"]["x"] / FT, r[lm + "_rj"]["H"]["h"] / FT, "r" + ls, lw=1,
                       label=f"{lm} fails {r['t']:.2f} s -> reject")
            ax[1].plot(r[lm + "_ct"]["H"]["x"] / FT, r[lm + "_ct"]["H"]["h"] / FT, "m" + ls, lw=1,
                       label=f"{lm} fails {r['t']:.2f} s -> continue")
            ax[1].plot(r["push_ct"]["H"]["x"] / FT, r["push_ct"]["H"]["h"] / FT, "b" + ls, lw=1,
                       label=f"pusher lane fails {r['t']:.2f} s -> continue")
    ax[1].axvline(300, color="r", lw=0.8); ax[1].axhline(50, color="r", lw=0.8)
    ax[1].set_xlim(0, 600); ax[1].set_ylim(0, 150)
    ax[1].set_xlabel("x [ft]"); ax[1].set_ylabel("h [ft]"); ax[1].legend(fontsize=7)
    ax[1].set_title("Paths around V1")
    fig.suptitle(title); fig.tight_layout(); fig.savefig(fname, dpi=130); plt.close(fig)


# =============================================================================
#  [v6] time-domain landing (standard and with a lift-rotor failure)
# =============================================================================
def landing_sim(ac, p, t_fail=None, dt=0.05, go_around=False):
    """Standard landing: decelerate at 50 ft + 5 m with rotors tilted aft,
    steep approach at V_app over the obstacle, flare to <= 1.5 m/s sink,
    touchdown, wheel brakes + pusher reverse. With t_fail the rotors are
    limited to the one-rotor-out capability after t_recog; with go_around the
    aircraft instead applies full pusher power and climbs away."""
    W, S, rho = ac["W"], ac["S"], ac["rho"]
    m = W / G
    CL_tr = p.k_CL_trans * CLhl(p)
    CD0 = ac["CD0"] + dCD0hl(p) + ac["n_rot"] * (p.f_rot_spin - p.f_rot_stop) * ac.get("kD", 1.0) / S
    Khl = 1 / (math.pi * ac["AR"] * p.e_highlift)
    thb = math.radians(p.theta_max)
    Tp0 = pusher_thrust(ac["P_push"], 0.0, ac["A_push"], p, rho)
    a_b = p.mu_brake * G + p.f_rev_push * Tp0 / m
    V = p.V_app
    s_ground = 0.5 * V + V * V / (2 * a_b)
    gam = math.atan(REQ.h_obs / max(REQ.s_field - s_ground - p.s_flare, 5.0))
    h1 = REQ.h_obs + 5.0
    u = 1.25 * math.sqrt(2 * W / (rho * S * p.CLmax_clean))
    h, w, x, t, E = h1, 0.0, 0.0, 0.0, 0.0
    phase, x_obs, w_touch = "decel", None, None
    keys = ("t", "x", "h", "u", "w", "ax", "az", "L", "Tv", "Th", "Tp", "Pr", "Pp", "th")
    hist = {k: [] for k in keys}
    while t < 300:
        q = 0.5 * rho * u * u
        failed = t_fail is not None and t >= t_fail
        active = failed and t >= t_fail + p.t_recog
        if phase == "decel" and u <= V:
            phase = "approach"
        if phase == "approach" and go_around and failed:
            phase = "go-around"
        if phase == "approach":
            if x_obs is None and h <= REQ.h_obs + 0.5:
                x_obs = x
            w_tgt = -V * math.sin(gam)
            h_flare = max((w * w - 1.5 ** 2) / (2 * 2.0), 0.0) if w < 0 else 0.0
            if h <= max(h_flare, 0.5):
                w_tgt = -1.5
            if h > REQ.h_obs + 0.5:
                w_tgt = -V * math.sin(gam)
        elif phase == "decel":
            w_tgt = 0.0
        elif phase == "go-around":
            w_tgt = 3.0
        else:
            w_tgt = 0.0
        az_c = max(min((w_tgt - w) / 1.2, 3.0), -3.0)
        if phase == "ground":
            CL = 0.3; L = q * S * CL; Tv = 0.0; th = 0.0
        else:
            CL = min(CL_tr, (W + m * az_c) / (q * S)) if q > 1 else 0.0
            L = q * S * CL
            Tv = max(W + m * az_c - L, 0.0)
            th = -thb if (phase == "decel" and not failed) else 0.0
        if failed and phase != "ground":
            cap = (vertical_capability(ac, p, u, w, lift_fmode(p))[1] if active
                   else Tv * (ac["n_rot"] - (1 if p.lift_lanes == 1 else 0.5)) / ac["n_rot"])
            Tv = min(Tv, cap); th = 0.0
        T = Tv / math.cos(th) if Tv > 0 else 0.0
        Pr = max(rotor_power(T, th, u, w, ac, p), 0.0) if T > 0 else 0.0
        Th, Tvert = T * math.sin(th), T * math.cos(th)
        D = q * S * (CD0 + Khl * CL * CL)
        if phase == "approach":
            Tp = D                                        # hold V_app
            Pp = max(Tp, 0) * max(u, 1.0) / p.eta_prop
        elif phase == "go-around":
            Pp = ac["P_push"]; Tp = pusher_thrust(Pp, u, ac["A_push"], p, rho)
        elif phase == "ground":
            Tp = -p.f_rev_push * Tp0 if u > 0.5 else 0.0
            Pp = 0.3 * ac["P_push"] if u > 0.5 else 0.0
        else:
            Tp, Pp = 0.0, 0.0
        Fric = p.mu_brake * max(W - L, 0.0) if phase == "ground" else 0.0
        ax = (Tp + Th - D - Fric) / m
        azr = (Tvert + L - W) / m if phase != "ground" else 0.0
        E += (Pr + Pp) / eta_bus(p) * dt
        for k, v in zip(keys, (t, x, h, u, w, ax, azr, L, Tvert, Th, Tp, Pr, Pp, math.degrees(th))):
            hist[k].append(v)
        u = max(u + ax * dt, 0.0); w += azr * dt
        x += u * dt; h += w * dt; t += dt
        if phase != "ground" and h <= 0.0:
            w_touch = w; h = 0.0; w = 0.0; phase = "ground"
        if phase == "ground" and u <= 0.3:
            break
        if phase == "go-around" and h > 120.0:
            break
    s_land = (x - x_obs) if x_obs is not None else None
    return dict(E=E, t=t, s=s_land, w_touch=w_touch, gamma=math.degrees(gam),
                hist={k: np.array(v) for k, v in hist.items()})


# =============================================================================
#  [v6] plots of the procedures
# =============================================================================
def plot_procedure(runs, fname, title, W, x_obs=None):
    """runs: list of (label, hist, style). Six panels: path, speeds,
    accelerations, power, lift share, cumulative energy."""
    fig, ax = plt.subplots(3, 2, figsize=(15, 12))
    for lab, H, ls in runs:
        t = H["t"]
        ax[0, 0].plot(H["x"], H["h"] / FT, ls, label=lab)
        ax[0, 1].plot(t, H["u"] / KT, ls, label=f"{lab}: forward speed")
        ax[1, 0].plot(t, H["ax"] / G, ls, label=f"{lab}: a_x")
        ax[1, 0].plot(t, H["az"] / G, ls, alpha=0.5, label=f"{lab}: a_z")
        ax[1, 1].plot(t, (H["Pr"] + H["Pp"]) / 1e3, ls, label=f"{lab}: total")
        ax[1, 1].plot(t, H["Pr"] / 1e3, ls, alpha=0.4, label=f"{lab}: lift rotors")
        tot = np.maximum(H["L"] + H["Tv"], 1.0)
        ax[2, 0].plot(t, H["L"] / tot * 100, ls, label=f"{lab}: wing share")
        E = np.cumsum((H["Pr"] + H["Pp"]) / 0.94) * (t[1] - t[0]) / 3.6e6
        ax[2, 1].plot(t, E, ls, label=lab)
        a2 = ax[0, 1]
        a2.plot(t, H["w"] * 196.85 / 100, ls, alpha=0.4, label=f"{lab}: vertical speed [100 fpm]")
    ax[0, 0].axhline(50, color="r", lw=0.8, ls="--")
    if x_obs is not None:
        ax[0, 0].axvline(x_obs, color="r", lw=0.8, ls="--")
    ax[0, 0].set_xlabel("x [m]"); ax[0, 0].set_ylabel("h [ft]"); ax[0, 0].set_title("Flight path")
    ax[0, 0].set_xlim(left=0)
    ax[0, 1].set_xlabel("t [s]"); ax[0, 1].set_ylabel("V [kt] / w [100 fpm]"); ax[0, 1].set_title("Velocities")
    ax[1, 0].set_xlabel("t [s]"); ax[1, 0].set_ylabel("acceleration [g]"); ax[1, 0].set_title("Accelerations")
    ax[1, 1].set_xlabel("t [s]"); ax[1, 1].set_ylabel("shaft power [kW]"); ax[1, 1].set_title("Power")
    ax[2, 0].set_xlabel("t [s]"); ax[2, 0].set_ylabel("% of vertical force"); ax[2, 0].set_title("Wing share of lift")
    ax[2, 1].set_xlabel("t [s]"); ax[2, 1].set_ylabel("battery-side energy [kWh]"); ax[2, 1].set_title("Energy")
    for a in ax.ravel():
        a.grid(alpha=0.3); a.legend(fontsize=7)
    fig.suptitle(title, fontsize=12)
    fig.tight_layout(); fig.savefig(fname, dpi=130); plt.close(fig)


def heliport_eval(r, p, h_field_ft=0.0):
    """Conceptual VTOL/vertiport compatibility check against FAA EB 105A.

    This is NOT a certification calculation. It checks the reference-aircraft
    envelope (MTOW/CD, distributed propulsion, two battery systems), HOGE power
    availability, and indicative TLOF/FATO/safety-area dimensions.
    """
    h = h_field_ft * FT
    ac = geometry(p, r["mtow"], r["ws"], r["AR"], r["D_rot"], h_field=h)
    ac.update(P_lift=r["P_lift"], P_push=r["P_push"])
    P_hoge = hover_power(p.k_download * ac["W"], ac["A_rot"], ac["rho"], p)
    hoge_margin = r["P_lift"] / max(P_hoge, 1e-9)
    # Simple vertical operation energy indication: 50-ft-equivalent rise/descent
    # from a steady hover at the selected field condition.
    h_v = max(p.h_vtol, 50.0 * FT)
    t_v = h_v / max(p.vz_vtol, 0.1)
    E_vto = P_hoge / eta_bus(p) * t_v
    E_vland = 0.9 * P_hoge / eta_bus(p) * t_v
    compatible = (r["mtow"] <= p.heliport_mtow_max and
                  ac["ctrl_dim"] <= p.heliport_cd_max and
                  p.heliport_prop_units >= 3 and
                  p.battery_systems >= 2 and
                  p.heliport_vmc and p.heliport_control_augmented and
                  hoge_margin >= 1.0)
    return dict(compatible=compatible, mtow_ok=r["mtow"] <= p.heliport_mtow_max,
                cd_ok=ac["ctrl_dim"] <= p.heliport_cd_max,
                battery_systems=p.battery_systems, prop_units=p.heliport_prop_units,
                hoge_margin=hoge_margin, ctrl_dim=ac["ctrl_dim"], rd_vtol=ac["RD_vtol"],
                t_v=t_v, E_vto=E_vto, E_vland=E_vland,
                TLOF=ac["RD_vtol"], FATO=2.0 * ac["RD_vtol"], safety_area=2.5 * ac["ctrl_dim"],
                field_altitude_ft=h_field_ft)


# =============================================================================
#  search, report, plots
# =============================================================================
def search(p, ws_list=(2600, 3000, 3400), AR_list=(15, 18),
           h_list=(20000, 25000, 30000), D_list=(4.0, 4.5), v_list=(225, 230,35)):
    rows, closed = [], []
    for v in v_list:
        pv = replace(p, v_cruise=v * KT)
        for ws in ws_list:
            for AR in AR_list:
                for D in D_list:
                    for h in h_list:
                        r = size(pv, ws, AR, h * FT, D)
                        if r:
                            rows.append(r)
                            if r["ok"]:
                                closed.append(r)
    pool = closed if closed else rows
    if not pool:
        return None, rows, closed
    ref = (min(r["mtow"] for r in pool), min(r["E_prim"] for r in pool),
           min(r["cost"]["generalised"] for r in pool))
    for r in pool:
        r["obj"] = (p.w_mass * r["mtow"] / ref[0] + p.w_energy * r["E_prim"] / ref[1]
                    + p.w_cost * r["cost"]["generalised"] / ref[2])
    return min(pool, key=lambda r: r["obj"]), rows, closed


def report(p, r, to_opt=None, table=None):
    ac = r["ac"]
    Bd = p.e_pack / WH
    print("=" * 76)
    print(f" DESIGN: Battery Density {Bd:.0f} Wh/kg, W/S {r['ws']} N/m^2 (max {REQ.ws_max:.0f}), AR {r['AR']}, 4 rotors D {r['D_rot']} m,"
          f" {r['v'] / KT:.0f} kt at {r['h_cr'] / FT:.0f} ft, block time {r['t_block'] * 60:.0f} min")
    print("=" * 76)
    print(f" MTOW {r['mtow']:.0f} kg (RFP limit {REQ.mtow_max:.0f}; design target {p.target_mtow:.0f}),  S {ac['S']:.1f} m^2,"
          f" b {ac['b']:.1f} m,  L/D cruise {r['ld_cr']:.1f} (CL {r['CL_cr']:.2f}),"
          f" L/D max {ac['LDmax']:.1f}")
    for k, v in r["parts"].items():
        print(f"   {k:<18s}{v:7.0f} kg {v / r['mtow'] * 100:5.1f} %")
    print(f" span margin to 15.2 m design cap: {p.span_max - ac['b']:+.2f} m; MTOW margin to 5.8 t target: {5800.0 - r['mtow']:+.0f} kg")
    print(f" power: lift {r['P_lift'] / 1e3:.0f} kW (sized by 5000 ft hot hover),"
          f" pusher {r['P_push'] / 1e3:.0f} kW, genset {r['P_gen'] / 1e3:.0f} kW SL")
    print(f" battery {'ENERGY' if r['m_bE'] >= r['m_bP'] else 'POWER'}-sized:"
          f" mission {r['E_mis'] / 3.6e6:.0f} kWh + 50 nmi reserve {r['E_res'] / 3.6e6:.0f} kWh"
          f" = {(r['E_mis'] + r['E_res']) / 3.6e6:.0f} kWh usable")
    print(f" mission: climb {r['s_cl']:.0f} + fuel cruise {r['r1']:.0f} + electric {REQ.range_el_cruise:.0f}"
          f" + glide {r['s_de']:.0f} nmi;  fuel {r['fuel']:.0f} + reserve {r['fuel_res']:.0f} kg;"
          f"  primary {r['E_prim'] / 3.6e9:.2f} MWh")
    t = to_opt or r["to"]
    print(f" TAKE-OFF (all 5 propulsors, rotors tilted {t['theta_max']:.0f} deg,"
          f" climb {t['w_to']:.2f} m/s to the obstacle, {t['w_after']:.1f} m/s after):")
    print(f"   50 ft reached at 300 ft (h = {t['h_obs'] / FT:.1f} ft), wing-borne at"
          f" {t['V_end'] / KT:.0f} kt after {t['t']:.0f} s / {t['x']:.0f} m,"
          f" energy {t['E'] / 3.6e6:.1f} kWh, peak bus {t['peak'] / 1e3:.0f} kW")
    if table:
        base = [e for th, wa, e in table if th == 0]
        if base:
            print(f"   vs. untilted rotors: {min(base) / 3.6e6:.1f} kWh ->"
                  f" saving {(min(base) - t['E_eq']) / 3.6e6:.1f} kWh (equivalent, height-credited)")
    if "gamma" in r["la"]:
        print(f" landing (time-domain {p.landing_mode}): {r['la']['s'] / FT:.0f} ft over 50 ft, approach"
              f" {p.V_app / KT:.0f} kt on a {r['la']['gamma']:.0f} deg path")
    #print(f" landing energy {r['la']['E'] / 3.6e6:.1f} kWh; power-off wing-only landing would"
        #  f" need {poweroff_landing_distance(ac, p)[0] / FT:.0f} ft")
    sysm, sys_total = systems_mass_breakdown_2035()
   # print(f" 2035 systems allowance {sys_total:.0f} kg (optimistic): " + ", ".join(f"{k} {v:.0f}" for k,v in sysm.items()))
 #   f5 = r.get("field_5000")
   # if f5:
     #   print(f" 5000 ft ISA+18F: 50-ft obstacle in {f5['x50'] / FT:.0f} ft with re-optimised initial climb {f5['to']['w_to']:.2f} m/s;"
      #        f" fixed {p.heli_approach_deg:.0f} deg approach landing {f5['landing_18'] / FT:.0f} ft")
   # hp0 = heliport_eval(r, p, 0.0)
   # hp5 = heliport_eval(r, p, 5000.0)
 #   print(f" HELIPORT / VERTIPORT CONOPS (FAA EB 105A reference-aircraft envelope, conceptual): {'PASS' if hp0['compatible'] else 'CASE-BY-CASE'};")
  #  print(f"   MTOW {r['mtow']:.0f}/{p.heliport_mtow_max:.0f} kg, controlling dimension {hp0['ctrl_dim']:.1f}/{p.heliport_cd_max:.1f} m,"
   #       f" {hp0['battery_systems']} battery systems, {hp0['prop_units']} propulsive units")
   # print(f"   HOGE margin: {hp0['hoge_margin']:.2f} x SL ISA+18; {hp5['hoge_margin']:.2f} x at 5000 ft ISA+18")
  #  print(f"   indicative EB 105A geometry: TLOF {hp0['TLOF']:.1f} m, FATO {hp0['FATO']:.1f} m, safety area {hp0['safety_area']:.1f} m;"
   #       f" vertical takeoff/landing energy {hp5['E_vto'] / 3.6e6:.1f}/{hp5['E_vland'] / 3.6e6:.1f} kWh")
 #   print("   caveat: existing heliports would require vertiport/heliport modification, site-specific obstacle/downwash review and regulatory approval.")
    print(f" generalised cost {r['cost']['generalised']:.0f} $/flight (DOC"
          f" {r['cost']['flight']:.0f} + passenger time {r['cost']['time_cost']:.0f})")
    print(f" cost: {r['cost']['acq'] / 1e6:.2f} M$, {r['cost']['flight']:.0f} $/flight,"
          f" {r['cost']['seat_nmi']:.3f} $/seat-nmi")
  #  print(" checks (>= 0 ok): " + ", ".join(f"{k} {v:+.2f}" for k, v in r["checks"].items()))
    print("=" * 76)


def metabook_crosschecks(p, r):
    """[v18] Metabook cross-checks printed with the report (not constraints)."""
    ac, m0 = r["ac"], r["mtow"]
    L, d = ac["L_fus"], math.sqrt(1.6 * 1.8)
    fr = L / d
    sw_fus = math.pi * d * L * (1 - 2 / fr) ** (2 / 3) * (1 + 1 / fr ** 2)
    S_exp = ac["S"] - ac["c"] * 1.6
    out = {}
    for col, (kw, kt, kf, kg, ke) in {"general aviation": (12, 10, 7, 0.057, 0.10),
                                      "transport": (49, 27, 24, 0.043, 0.17)}.items():
        out[col] = (kt * (ac["S_ht"] + ac["S_vt"]) + kf * sw_fus + (kg + ke) * m0,
                    kw * S_exp)                     # (airframe w/o wing, wing)
    P_shp = r["P_gen"] / HP
    m_ts_roskam = P_shp ** 0.9306 * 10 ** -0.1205 * LB          # Eq. 7.20, 1985 engines
    m_ts_code = r["P_gen"] / 1e3 / (p.sp_turboshaft * p.eta_generator)
    print(" METABOOK CROSS-CHECKS (information):")
    print(f"   airframe excl. wing: code {r['parts']['airframe']:.0f} kg | Table 7.1 GA"
          f" {out['general aviation'][0]:.0f} kg, transport {out['transport'][0]:.0f} kg")
    print(f"   wing: code {r['parts']['wing']:.0f} kg | Table 7.1 GA {out['general aviation'][1]:.0f},"
          f" transport {out['transport'][1]:.0f} kg | Eq. 7.11 x{p.k_wing_comp:.2f}"
          f" {wing_mass_raymer(p, ac['W'], ac['S'], ac['AR'], r['n_ult']):.0f} kg")
    print(f"   turboshaft: code {m_ts_code:.0f} kg | Roskam Eq. 7.20 {m_ts_roskam:.0f} kg (1985 technology)")
    print(f"   load factors: manoeuvre {r['n_man']:.2f} (Eq. 11.3), gust {r['n_gust']:.2f}"
          f" (Eq. 11.4), n_ult {r['n_ult']:.2f}")
    c = r.get("climb_FAR23", {})
    if c:
        print(f"   FAR 23.2120: a {c['a'] * 100:.1f} % (>= 4), b {c['b'] * 100:.1f} % (>= 1),"
              f" c {c['c'] * 100:.1f} % (>= 3); ceiling ROC {c['roc_ceiling'] / (FT / 60):.0f} fpm"
              f" (>= {p.roc_ceiling / (FT / 60):.0f})")
    return out


def plot_takeoff(r, p, fname):
    h = r["hist"]
    fig, ax = plt.subplots(2, 2, figsize=(14, 9))
    W = h["L"][0] * 0 + (h["L"] + h["Tv"]).max()
    a = ax[0, 0]
    a.plot(h["x"], h["h"] / FT, "k-")
    a.axvline(REQ.s_field, color="r", ls="--", lw=0.8); a.axhline(50, color="r", ls="--", lw=0.8)
    a.plot(REQ.s_field, 50, "ro"); a.set_xlim(0, max(3 * REQ.s_field, h["x"][-1] * 0.4))
    a.set_ylim(0, max(80, h["h"].max() / FT * 1.1))
    a.set_xlabel("x [m]"); a.set_ylabel("h [ft]"); a.set_title("Flight path (50 ft at 300 ft)")
    a = ax[0, 1]
    tot = h["L"] + h["Tv"]
    a.stackplot(h["t"], h["L"] / tot * 100, h["Tv"] / tot * 100,
                labels=["wing lift", "rotor vertical thrust"], colors=["tab:blue", "tab:orange"], alpha=.8)
    a2 = a.twinx(); a2.plot(h["t"], h["u"] / KT, "k--"); a2.set_ylabel("V [kt]")
    a.set_ylabel("share of vertical force [%]"); a.set_xlabel("t [s]"); a.legend(loc="center right")
    a.set_title("Lift share wing / rotors")
    a = ax[1, 0]
    a.stackplot(h["t"], h["Pr"] / 1e3, h["Pp"] / 1e3, labels=["lift rotors", "pusher"],
                colors=["tab:orange", "tab:green"], alpha=.8)
    a.set_ylabel("shaft power [kW]"); a.set_xlabel("t [s]"); a.legend(); a.set_title("Power split")
    a = ax[1, 1]
    a.plot(h["t"], h["Th"] / 1e3, label="rotor forward thrust")
    a.plot(h["t"], h["Tp"] / 1e3, label="pusher thrust")
    a3 = a.twinx(); a3.plot(h["t"], h["th"], "r:", label="tilt"); a3.set_ylabel("rotor tilt [deg]", color="r")
    a.set_ylabel("thrust [kN]"); a.set_xlabel("t [s]"); a.legend(); a.set_title("Forward thrust sources")
    fig.suptitle(f"Tilted-rotor STOL take-off, sea level ISA+18, MTOW {r['mtow'] if 'mtow' in r else ''}")
    fig.tight_layout(); fig.savefig(fname, dpi=140); plt.close(fig)


# =============================================================================
def landing_scan(ac, p):
    """Standard landing plus a lift failure at every moment of the approach:
    worst touchdown sink if the aircraft continues to land, and the last
    moment from which a go-around still works (LDP)."""
    L = landing_sim(ac, p)
    Hl = L["hist"]
    t_app = Hl["t"][int(np.argmax(Hl["u"] <= p.V_app + 0.01))]
    worst, t_ldp, rows = 0.0, None, []
    for dtf in np.arange(-3.0, 6.01, 0.5):
        Lf = landing_sim(ac, p, t_fail=t_app + dtf)
        Lg = landing_sim(ac, p, t_fail=t_app + dtf, go_around=True)
        sink = -Lf["w_touch"] if Lf["w_touch"] is not None else 99.0
        ga = Lg["hist"]["h"][-1] > 100
        rows.append((dtf, sink, ga))
        if ga:
            t_ldp = dtf
    # failures after the LDP must be landed: worst sink among those
    after = [s for d, s, g in rows if t_ldp is None or d > t_ldp]
    worst = max(after) if after else 0.0
    return dict(L=L, rows=rows, t_ldp=t_ldp, worst_after_ldp=worst,
                ok=worst <= p.w_td_emerg and L["s"] is not None and L["s"] <= REQ.s_field)


def evaluate_config(p, geo, laws):
    """Size the given configuration on the given geometry, find the smallest
    rotor margin with a valid V1 (emergency rating fixed), scan the landing."""
    res = design_takeoff3(p, geo, laws)
    if res is None:
        r = size(p, geo["ws"], geo["AR"], geo["h_cr"], geo["D_rot"])
        ls = landing_scan(r["ac"], p) if r else None
        return dict(ok=False, mtow=r["mtow"] if r else None, ls=ls)
    km, r, pk, law, a, n = res
    ls = landing_scan(r["ac"], pk)
    return dict(ok=True, km=km, r=r, p=pk, law=law, a=a, ls=ls, mtow=r["mtow"])


# =============================================================================
#  [v10] two-stage search, design-decision study, dimensioned drawing
# =============================================================================
GRID = dict(ws=(2600, 3000, 3400, 3800, 4200, 4600, 5000, 5400), AR=(10, 12, 14, 16, 18, 20),
            D=(3.5, 4.0, 4.5, 5.0), h=(6000, 8000, 10000, 11000, 12000, 12500))


def search_fast(p, grid=GRID, top=6):
    """Stage 1: surrogate sizing on the whole grid (a few seconds).
    Stage 2: full physics (take-off/landing simulations) for the best 'top'."""
    rows, all_rows = [], []
    for ws in grid["ws"]:
        for AR in grid["AR"]:
            for D in grid["D"]:
                for h in grid["h"]:
                    r = size(p, ws, AR, h * FT, D, fast=True)
                    if r:
                        all_rows.append(r)
                    if r and (r["ok"] or (all(v >= 0 for k, v in r["checks"].items() if k != "MTOW"))):
                        rows.append(r)                   # keep MTOW-violators for reporting
    if not rows:                                         # [v18] nothing closes: least violation
        viol = lambda r: sum(-v for v in r["checks"].values() if v < 0)
        rows = sorted(all_rows, key=viol)[:max(5 * top, 30)]
        bad = sorted({k for r in rows[:top] for k, v in r["checks"].items() if v < 0})
        print(" WARNING: no grid point meets all constraints except MTOW; continuing with the"
              " least-violating designs. Violated: " + ", ".join(bad))
    ref = (min(r["mtow"] for r in rows), min(r["E_prim"] for r in rows),
           min(r["cost"]["generalised"] for r in rows))
    for r in rows:
        r["obj"] = (p.w_mass * r["mtow"] / ref[0] + p.w_energy * r["E_prim"] / ref[1]
                    + p.w_cost * r["cost"]["generalised"] / ref[2])
    span_rows = [r for r in rows if r["AR"] <= p.AR_max and r["ac"]["b"] <= p.span_max + 1e-9]
    target_rows = [r for r in span_rows if r["ok"] and r["mtow"] <= p.target_mtow]
    ok_rows = [r for r in span_rows if r["ok"]]
    span_rows = span_rows or rows                         # [v18] fallback
    pool = target_rows if target_rows else (ok_rows if ok_rows else sorted(span_rows, key=lambda r: r["mtow"])[:top])
    cand = sorted(pool, key=lambda r: r["obj"])[:top]
    full = [size(p, c["ws"], c["AR"], c["h_cr"], c["D_rot"]) for c in cand]
    full = [f for f in full if f and (f["ok"] or not ok_rows)]
    if not full:                                          # [v18] full physics closed nothing
        print(" WARNING: full-physics sizing did not close for the candidates; fast result shown")
        full = cand
    for f in full:
        f["obj"] = (p.w_mass * f["mtow"] / ref[0] + p.w_energy * f["E_prim"] / ref[1]
                    + p.w_cost * f["cost"]["generalised"] / ref[2])
    return min(full, key=lambda r: r["obj"]), rows


def profiles(rows, fname, title):
    """For every value of one design variable: the best design over all the
    others (profile). Shows how much each decision really matters."""
    keys = [("AR", "AR", "aspect ratio"), ("ws", "ws", "W/S [N/m$^2$]"),
            ("D_rot", "D", "rotor diameter [m]"), ("h_cr", "h", "cruise altitude [ft]")]
    fig, axs = plt.subplots(2, 2, figsize=(13, 9))
    for ax, (k, _, lab) in zip(axs.ravel(), keys):
        vals = sorted({r[k] for r in rows})
        best = [min((r for r in rows if r[k] == v), key=lambda r: r["obj"]) for v in vals]
        xs = [v / FT if k == "h_cr" else v for v in vals]
        ax.plot(xs, [b["mtow"] for b in best], "ko-", label="MTOW (best design at this value)")
        ax.set_xlabel(lab); ax.set_ylabel("MTOW [kg]"); ax.grid(alpha=0.3)
        a2 = ax.twinx()
        a2.plot(xs, [b["E_prim"] / 3.6e9 for b in best], "bs--", label="primary energy")
        a2.plot(xs, [b["cost"]["generalised"] / 1000 for b in best], "r^:", label="gen. cost [k$]")
        a2.set_ylabel("energy [MWh] / cost [k$ per flight]")
        h1, l1 = ax.get_legend_handles_labels(); h2, l2 = a2.get_legend_handles_labels()
        ax.legend(h1 + h2, l1 + l2, fontsize=7, loc="upper center")
    fig.suptitle(title); fig.tight_layout(); fig.savefig(fname, dpi=130); plt.close(fig)


def ar_wing_study(p, ref, fname):
    """AR sweep at the chosen W/S, D and altitude: wing mass split and MTOW
    with the bending model vs the simple areal model."""
    ARs = np.arange(8, 24.1, 1.0)
    out = {"bending": [], "areal": []}
    parts = []
    for AR in ARs:
        for mdl in out:
            r = size(replace(p, wing_model=mdl), ref["ws"], AR, ref["h_cr"], ref["D_rot"], fast=True)
            out[mdl].append(r["mtow"] if r else np.nan)
            if mdl == "bending":
                if r:
                    wm, Mm, Mh = wing_mass(p, r["ac"]["W"], r["ac"]["S"], AR, r["ac"]["y_boom"], r["n_ult"])
                    parts.append((r["parts"]["wing"], r["parts"]["battery"], r["ld_cr"], Mm, Mh))
                else:
                    parts.append((np.nan,) * 5)
    parts = np.array(parts)
    fig, ax = plt.subplots(1, 2, figsize=(13, 5))
    ax[0].plot(ARs, out["bending"], "k-o", label="MTOW, bending wing model (v10)")
    ax[0].plot(ARs, out["areal"], "k--", label="MTOW, areal wing model (v9)")
    ax[0].axvline(ref["AR"], color="r", lw=0.8)
    ax[0].set_xlabel("aspect ratio"); ax[0].set_ylabel("MTOW [kg]"); ax[0].grid(alpha=0.3)
    ax[0].legend(fontsize=8)
    ax[1].plot(ARs, parts[:, 0], "g-o", label="wing mass [kg]")
    ax[1].plot(ARs, parts[:, 1], "b-s", label="battery mass [kg]")
    a2 = ax[1].twinx(); a2.plot(ARs, parts[:, 2], "r:", label="L/D cruise"); a2.set_ylabel("L/D", color="r")
    ax[1].set_xlabel("aspect ratio"); ax[1].set_ylabel("kg"); ax[1].grid(alpha=0.3); ax[1].legend(fontsize=8)
    fig.suptitle(f"Aspect ratio study at W/S {ref['ws']}, D {ref['D_rot']} m, {ref['h_cr'] / FT:.0f} ft"
                 " (wing sized by manoeuvre OR rotor/boom bending)")
    fig.tight_layout(); fig.savefig(fname, dpi=130); plt.close(fig)
    return ARs, out, parts


def draw_threeview(r, p, fname):
    """Dimensioned straight-line multi-view drawing (top, side, front, iso)."""
    ac = r["ac"]
    S, b, D = ac["S"], ac["b"], r["D_rot"]
    lam = p.taper
    c_r = 2 * S / (b * (1 + lam)); c_t = lam * c_r
    L = ac["L_fus"]; wf, hf = 1.6, 1.8
    zg = 0.55; zt = zg + hf
    x_le = 0.40 * L - 0.25 * c_r
    xt_le = x_le + 0.35 * (c_r - c_t)
    yb = ac["y_boom"]
    xf, xa = x_le - D / 2 - 0.3, x_le + c_r + D / 2 + 0.3
    S_ht, S_vt, l_t = ac["S_ht"], ac["S_vt"], ac["l_t"]
    b_ht = math.sqrt(4.5 * S_ht); c_ht = S_ht / b_ht
    h_vt = math.sqrt(1.5 * S_vt); c_vt = S_vt / h_vt
    x_ht = x_le + 0.25 * c_r + l_t - 0.25 * c_ht
    Dp = p.D_push; z_p = zg + 0.72 * hf
    zr = zt + 0.25
    lines = []

    def add(pts, col="k", lw=1.3):
        lines.append((np.array(pts, float), col, lw))

    def ring(cx, cy, cz, rad, plane, col="tab:red"):
        a = np.linspace(0, 2 * math.pi, 25)
        if plane == "xy":
            add(np.c_[cx + rad * np.cos(a), cy + rad * np.sin(a), np.full_like(a, cz)], col, 1.0)
        else:
            add(np.c_[np.full_like(a, cx), cy + rad * np.cos(a), cz + rad * np.sin(a)], col, 1.0)

    st = [0.0, 1.4, 3.0, 0.62 * L, 0.78 * L, L]
    wid = [0.0, wf * .8, wf, wf, wf * .6, 0.25]
    hup = [zg + .9, zg + hf * .9, zt, zt, zg + hf * .8, zg + hf * .75]
    hlo = [zg + .9, zg + .15, zg, zg, zg + .45, zg + hf * .55]
    for s in (1, -1):
        add([(x, s * w / 2, z) for x, w, z in zip(st, wid, hup)])
        add([(x, s * w / 2, z) for x, w, z in zip(st, wid, hlo)])
    for x, w, zu, zl in zip(st, wid, hup, hlo):
        add([(x, -w / 2, zl), (x, w / 2, zl), (x, w / 2, zu), (x, -w / 2, zu), (x, -w / 2, zl)], "0.5", 0.7)
    dih = math.radians(2.0)
    for s in (1, -1):
        add([(x_le, s * wf / 2, zt), (xt_le, s * b / 2, zt + b / 2 * dih), (xt_le + c_t, s * b / 2, zt + b / 2 * dih),
             (x_le + c_r, s * wf / 2, zt), (x_le, s * wf / 2, zt)], "tab:blue", 1.6)
        zb = zt + yb * dih
        add([(xf, s * yb, zb), (xa, s * yb, zb)], "0.2", 2.0)
        for xr in (xf, xa):
            ring(xr, s * yb, zr, D / 2, "xy")
            add([(xr - D / 2, s * yb, zr), (xr + D / 2, s * yb, zr)], "tab:red", 1.5)
            add([(xr, s * yb, zb), (xr, s * yb, zr)], "0.2", 1.2)
    add([(x_ht, -b_ht / 2, zt + h_vt), (x_ht, b_ht / 2, zt + h_vt), (x_ht + c_ht, b_ht / 2, zt + h_vt),
         (x_ht + c_ht, -b_ht / 2, zt + h_vt), (x_ht, -b_ht / 2, zt + h_vt)], "tab:blue", 1.4)
    add([(x_ht - 0.6, 0, zg + hf * .8), (x_ht, 0, zt + h_vt), (x_ht + c_ht, 0, zt + h_vt),
         (L - 0.1, 0, zg + hf * .75)], "tab:purple", 1.4)
    ring(L + 0.25, 0, z_p, Dp / 2, "yz", "tab:green")
    add([(L + 0.25, -Dp / 2, z_p), (L + 0.25, Dp / 2, z_p)], "tab:green", 1.5)
    add([(2.0, 0, zg), (2.0, 0, 0)], "0.3", 1.2)
    for s in (1, -1):
        add([(x_le + 0.6 * c_r, s * 0.8, zg), (x_le + 0.6 * c_r, s * 1.4, 0)], "0.3", 1.2)

    def proj(P, view):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        if view == "top":
            return y, -x
        if view == "side":
            return x, z
        if view == "front":
            return y, z
        az, el = math.radians(40), math.radians(22)
        xr_ = x * math.cos(az) + y * math.sin(az); yr_ = -x * math.sin(az) + y * math.cos(az)
        return yr_, z * math.cos(el) - xr_ * math.sin(el)

    fig = plt.figure(figsize=(17, 12))
    gs = fig.add_gridspec(2, 2)
    axes = {"top": fig.add_subplot(gs[0, 0]), "side": fig.add_subplot(gs[0, 1]),
            "front": fig.add_subplot(gs[1, 0]), "iso": fig.add_subplot(gs[1, 1])}
    for v, ax in axes.items():
        for P3, col, lw in lines:
            u, w = proj(P3, v)
            ax.plot(u, w, "-", color=col, lw=lw)
        ax.set_aspect("equal"); ax.grid(alpha=0.2)

    def dim(ax, p1, p2, text, off=(0, 0), col="0.25"):
        ax.annotate("", xy=p2, xytext=p1, arrowprops=dict(arrowstyle="<->", color=col, lw=0.9))
        ax.text((p1[0] + p2[0]) / 2 + off[0], (p1[1] + p2[1]) / 2 + off[1], text, ha="center",
                va="center", fontsize=8, color=col, bbox=dict(fc="white", ec="none", alpha=0.8))

    a = axes["top"]
    dim(a, (-b / 2, 1.5), (b / 2, 1.5), f"span b = {b:.1f} m")
    dim(a, (b / 2 + 0.8, 0), (b / 2 + 0.8, -L), f"L = {L:.1f} m", off=(0.9, 0))
    dim(a, (-b / 2 - 0.5, -xt_le), (-b / 2 - 0.5, -(xt_le + c_t)), f"c_t\n{c_t:.2f}", off=(-0.9, 0))
    dim(a, (1.1, -x_le), (1.1, -(x_le + c_r)), f"c_r {c_r:.2f}", off=(0.9, 0))
    dim(a, (yb - D / 2, -xf + D / 2 + 0.5), (yb + D / 2, -xf + D / 2 + 0.5), f"D = {D:.1f} m")
    dim(a, (0, -xf - D / 2 - 0.6), (yb, -xf - D / 2 - 0.6), f"y = {yb:.2f} m", off=(0, -0.35))
    dim(a, (-yb - 0.6, -xf), (-yb - 0.6, -xa), f"boom {xa - xf:.1f} m", off=(-1.1, 0))
    dim(a, (-b_ht / 2, -(x_ht + c_ht) - 0.6), (b_ht / 2, -(x_ht + c_ht) - 0.6), f"b_HT = {b_ht:.1f} m")
    a.set_xlim(-b / 2 - 2.5, b / 2 + 2.5); a.set_ylim(-L - 2.0, 2.5)
    a.set_title(f"Top view  --  S = {S:.1f} m$^2$, AR = {r['AR']}, taper {lam}, W/S = {r['ws']} N/m$^2$")
    a.set_xlabel("y [m]"); a.set_ylabel("-x [m]")
    a = axes["side"]
    dim(a, (0, -0.6), (L, -0.6), f"L = {L:.1f} m")
    dim(a, (L + 1.8, 0), (L + 1.8, zt + h_vt), f"H = {zt + h_vt:.1f} m", off=(0.8, 0))
    dim(a, (L + 0.9, z_p - Dp / 2), (L + 0.9, z_p + Dp / 2), f"D_p\n{Dp:.1f} m", off=(0.7, 0))
    dim(a, (xf, zr + 0.8), (xa, zr + 0.8), f"rotor hubs {xa - xf:.1f} m apart")
    a.set_xlim(-1.0, L + 3.5)
    dim(a, (x_le, zt + 0.35), (x_le + c_r, zt + 0.35), f"c_r {c_r:.2f}", off=(0, 0.3))
    a.axhline(0, color="0.6", lw=0.8)
    a.set_title("Side view (T-tail, pusher in tail cone, rotors above the wing)")
    a.set_xlabel("x [m]"); a.set_ylabel("z [m]"); a.set_ylim(-1.5, zt + h_vt + 1.5)
    a = axes["front"]
    dim(a, (-b / 2, -0.7), (b / 2, -0.7), f"b = {b:.1f} m")
    dim(a, (-yb, zr + 0.7), (yb, zr + 0.7), f"boom spacing {2 * yb:.1f} m")
    dim(a, (-wf / 2, zg - 0.3), (wf / 2, zg - 0.3), f"{wf:.1f} m", off=(0, -0.3))
    a.axhline(0, color="0.6", lw=0.8)
    a.set_xlim(-b / 2 - 1.0, b / 2 + 1.0); a.set_ylim(-1.4, zt + h_vt + 1.2)
    a.set_title(f"Front view (4 lift rotors D {D:.1f} m, 2 motors each; pusher D {Dp:.1f} m)")
    a.set_xlabel("y [m]"); a.set_ylabel("z [m]")
    axes["iso"].set_title("Isometric"); axes["iso"].set_xticks([]); axes["iso"].set_yticks([])
    fig.suptitle(f"Hybrid lift + cruise commuter -- MTOW {r['mtow']:.0f} kg, {r['v'] / KT:.0f} kt at"
                 f" {r['h_cr'] / FT:.0f} ft -- schematic, dimensions in m", fontsize=13)
    fig.tight_layout(); fig.savefig(fname, dpi=140); plt.close(fig)


def all_electric(r, p, h, keep_reserve=True, V=None):
    """[v11] point-to-point flight entirely on the battery: take-off, climb
    (1500 fpm at v_climb), cruise at 230 kt, descent law, landing, taxi.
    The aircraft carries only the IFR fuel reserve (mission fuel not loaded).
    keep_reserve: the 50 nmi battery reserve (genset-failure case) stays."""
    ac = r["ac"]
    V = V if V else r["v"]
    W = (r["mtow"] - r["fuel"]) * G
    usable = r["parts"]["battery"] * p.e_pack * p.dod
    ld_cl, _ = LD(ac, W, p.v_climb, h / 2)
    ld_cr, CL = LD(ac, W, V, h)
    if CL > p.CL_cruise_max:
        return None
    t_cl = h / REQ.roc_min
    s_cl = p.v_climb * t_cl / NMI
    E_cl = (W * h + W * s_cl * NMI / ld_cl) / eta_batt_thr(p)
    s_de, t_de, E_de, fpow = descent_profile(ac, p, W, h, V)
    E_fix = (r["to"]["E"] + r["la"]["E"]) / p.eta_batt + p.e_ground
    E_left = usable - (r["E_res"] if keep_reserve else 0.0) - E_fix - E_cl - E_de
    if E_left <= 0:
        return dict(h=h, range=0.0, feasible=False)
    e_nmi = W * NMI / (ld_cr * eta_batt_thr(p))
    R_cr = E_left / e_nmi
    t = t_cl + R_cr * NMI / V + t_de + r["to"]["t"] + 120
    return dict(h=h, range=s_cl + R_cr + s_de, cruise=R_cr, s_cl=s_cl, s_de=s_de, feasible=True,
                E=dict(takeoff_landing_taxi=E_fix, climb=E_cl, cruise=E_left, descent=E_de,
                       reserve=r["E_res"] if keep_reserve else 0.0),
                ld=ld_cr, t=t, fpow=fpow)


def plot_all_electric(r, p, fname):
    hs = np.arange(2000, 30001, 1000) * FT
    fig, ax = plt.subplots(1, 2, figsize=(14, 5.5))
    best = {}
    for keep, ls in ((True, "-"), (False, "--")):
        res = [all_electric(r, p, h, keep) for h in hs]
        ok = [(h, x) for h, x in zip(hs, res) if x and x["feasible"]]
        lab = "keeping the 50 nmi battery reserve" if keep else "using the battery reserve"
        ax[0].plot([h / FT for h, _ in ok], [x["range"] for _, x in ok], "k" + ls, label=lab)
        b = max(ok, key=lambda o: o[1]["range"])
        best[keep] = b[1]
        ax[0].plot(b[0] / FT, b[1]["range"], "r*", ms=13)
    ax[0].set_xlabel("cruise altitude [ft]"); ax[0].set_ylabel("all-electric range [nmi]")
    ax[0].set_title("Point-to-point range on the battery alone (230 kt)"); ax[0].grid(alpha=0.3)
    ax[0].legend()
    x = best[False]
    labels = list(x["E"].keys()); vals = [x["E"][k] / 3.6e6 for k in labels]
    x2 = best[True]
    vals2 = [x2["E"][k] / 3.6e6 for k in labels]
    yy = np.arange(len(labels))
    ax[1].barh(yy - 0.2, vals2, 0.4, label=f"reserve kept: {x2['range']:.0f} nmi")
    ax[1].barh(yy + 0.2, vals, 0.4, label=f"reserve used: {x['range']:.0f} nmi")
    ax[1].set_yticks(yy); ax[1].set_yticklabels(labels); ax[1].set_xlabel("battery energy [kWh]")
    ax[1].set_title("Where the battery energy goes (best altitude)"); ax[1].legend()
    fig.tight_layout(); fig.savefig(fname, dpi=130); plt.close(fig)
    return best


def plot_descent(r, p, fname):
    ac = r["ac"]; W = (r["mtow"] - r["fuel"]) * G
    hs = np.linspace(r["h_cr"], p.h_desc_end, 60)
    fig, ax = plt.subplots(figsize=(9, 5))
    for V, ls in ((None, "-"), (180 * KT, "--"), (150 * KT, ":")):
        Vv = V if V else r["v"]
        rodg = [Vv / LD(ac, W, Vv, h)[0] / (FT / 60) for h in hs]
        ax.plot(rodg, hs / FT, "k" + ls, label=f"natural glide rate at {Vv / KT:.0f} kt")
    ax.axvline(p.rod_target / (FT / 60), color="r", label="target rate of descent")
    ax.set_xlabel("rate of descent [fpm]"); ax.set_ylabel("altitude [ft]"); ax.grid(alpha=0.3)
    ax.set_title("Descent law: glide where the glide is shallower than the target, power below")
    ax.legend(); fig.tight_layout(); fig.savefig(fname, dpi=130); plt.close(fig)


def electric_trip(r, p, R_nmi, h, V=None):
    """[v13] fly R_nmi entirely on the battery at cruise altitude h:
    take-off, climb (1500 fpm), cruise at V, descent law, landing, taxi,
    plus all system loads. Mission fuel not loaded (IFR fuel reserve only).
    Returns None if the altitude cannot be reached within R_nmi."""
    ac = r["ac"]
    V = V if V else r["v"]
    W = (r["mtow"] - r["fuel"]) * G
    ld_cl, _ = LD(ac, W, p.v_climb, h / 2)
    ld_cr, CL = LD(ac, W, V, h)
    if CL > p.CL_cruise_max:
        return None
    t_cl = h / REQ.roc_min
    s_cl = p.v_climb * t_cl / NMI
    s_de, t_de, E_de, _ = descent_profile(ac, p, W, h, V)
    R_cr = R_nmi - s_cl - s_de
    if R_cr < 0:
        return None
    t_cr = R_cr * NMI / V
    E_cl = (W * h + W * s_cl * NMI / ld_cl) / eta_batt_thr(p)
    E_cr = W * R_cr * NMI / (ld_cr * eta_batt_thr(p))
    P_cr_shaft = W * V / ld_cr
    E_aux = (aux_power(p, h / 2, r["P_push"])[0] * t_cl + aux_power(p, h, P_cr_shaft)[0] * t_cr
             + aux_power(p, h / 2)[0] * t_de + aux_power(p, 0.0, r["P_lift"])[0] * 600.0) / p.eta_batt
    E_fix = (r["to"]["E"] + r["la"]["E"]) / p.eta_batt + p.e_ground
    E = E_cl + E_cr + E_de + E_aux + E_fix
    usable = r["parts"]["battery"] * p.e_pack * p.dod
    t_block = (t_cl + t_cr + t_de + r["to"]["t"] + 120.0) / 3600 + p.t_taxi
    return dict(R=R_nmi, h=h, E=E, usable=usable, feasible=E <= usable, margin=usable - E,
                keeps_reserve=E + r["E_res"] <= usable, t_block=t_block, ld=ld_cr,
                split=dict(fixed=E_fix, climb=E_cl, cruise=E_cr, descent=E_de, systems=E_aux))


def best_electric_trip(r, p, R_nmi, h_max):
    trips = [electric_trip(r, p, R_nmi, h * FT) for h in range(4000, int(h_max / FT) + 1, 500)]
    trips = [t for t in trips if t]
    ok = [t for t in trips if t["feasible"]]
    if ok:
        return min(ok, key=lambda t: t["E"])
    return min(trips, key=lambda t: t["E"]) if trips else None


def max_electric_range(r, p, h_max):
    lo, hi = 20.0, 500.0
    for _ in range(25):
        mid = 0.5 * (lo + hi)
        t = best_electric_trip(r, p, mid, h_max)
        if t and t["feasible"]:
            lo = mid
        else:
            hi = mid
    return lo


# =============================================================================
#  [v17b] spec table and take-off time history
# =============================================================================
def spec_rows(p, r, to_info=None):
    """Current design as (group, quantity, value, unit) rows."""
    ac = r["ac"]
    lam = p.taper
    c_r = 2 * ac["S"] / (ac["b"] * (1 + lam))
    rows = [
        ("Design", "cruise speed", r["v"] / KT, "kt"),
        ("Design", "cruise altitude", r["h_cr"] / FT, "ft"),
        ("Design", "wing loading W/S", r["ws"], "N/m^2"),
        ("Design", "wing loading W/S", r["ws"] / G, "kg/m^2"),
        ("Design", "W/S upper limit", REQ.ws_max, "N/m^2"),
        ("Design", "aspect ratio", r["AR"], "-"),
        ("Design", "lift rotors", ac["n_rot"], "-"),
        ("Design", "lift rotor diameter", r["D_rot"], "m"),
        ("Design", "pusher diameter", p.D_push, "m"),
        ("Design", "battery pack energy density", p.e_pack / WH, "Wh/kg"),
        ("Design", "high-lift CLmax (landing / take-off)", f"{CLhl(p):.2f} / {CLhl(p_takeoff(p)):.2f}", "-"),
        ("Geometry", "wing area S", ac["S"], "m^2"),
        ("Geometry", "span b", ac["b"], "m"),
        ("Geometry", "root / tip chord", f"{c_r:.2f} / {lam * c_r:.2f}", "m"),
        ("Geometry", "mean chord", ac["c"], "m"),
        ("Geometry", "fuselage length", ac["L_fus"], "m"),
        ("Geometry", "boom lateral position y", ac["y_boom"], "m"),
        ("Geometry", "horizontal / vertical tail area", f"{ac['S_ht']:.2f} / {ac['S_vt']:.2f}", "m^2"),
        ("Geometry", "controlling dimension", ac["ctrl_dim"], "m"),
        ("Mass", "MTOW", r["mtow"], "kg"),
    ]
    rows += [("Mass", k.replace("_", " "), v, "kg") for k, v in r["parts"].items()]
    rows += [
        ("Aero", "CD0 (clean)", ac["CD0"], "-"),
        ("Aero", "L/D max", ac["LDmax"], "-"),
        ("Aero", "L/D cruise (CL)", f"{r['ld_cr']:.1f} ({r['CL_cr']:.2f})", "-"),
        ("Power", "installed lift power", r["P_lift"] / 1e3, "kW"),
        ("Power", "installed pusher power", r["P_push"] / 1e3, "kW"),
        ("Power", "genset power (SL)", r["P_gen"] / 1e3, "kW"),
        ("Power", "power loading P_total/W", (r["P_lift"] + r["P_push"]) / (r["mtow"] * G), "W/N"),
        ("Energy", "battery mission energy", r["E_mis"] / 3.6e6, "kWh"),
        ("Energy", "battery reserve energy", r["E_res"] / 3.6e6, "kWh"),
        ("Energy", "battery sizing", "energy" if r["m_bE"] >= r["m_bP"] else "power", "-"),
        ("Energy", "primary energy 400 nmi mission", r["E_prim"] / 3.6e6, "kWh"),
        ("Mission", "climb / fuel cruise / electric / descent",
         f"{r['s_cl']:.0f} / {r['r1']:.0f} / {REQ.range_el_cruise:.0f} / {r['s_de']:.0f}", "nmi"),
        ("Mission", "block time", r["t_block"] * 60, "min"),
        ("Field", "take-off (sizing law): height at 300 ft", r["to"]["h_obs"] / FT, "ft"),
        ("Field", "take-off energy (sizing law)", r["to"]["E"] / 3.6e6, "kWh"),
        ("Field", "landing distance over 50 ft", r["la"]["s"] / FT, "ft"),
        ("Cost", "acquisition", r["cost"]["acq"] / 1e6, "M$"),
        ("Cost", "DOC per flight", r["cost"]["flight"], "$"),
        ("Cost", "seat-nmi cost", r["cost"]["seat_nmi"], "$/seat-nmi"),
    ]
    if to_info:
        rows += [("Take-off (V1 design)", k, v, u) for k, v, u in to_info]
    rows += [("Constraint margin (>= 0 ok)", k, v, "-") for k, v in r["checks"].items()]
    return rows


def _fmt(v, dec=","):
    if isinstance(v, str):
        return v
    if isinstance(v, (int, np.integer)) or (isinstance(v, float) and float(v).is_integer() and abs(v) >= 100):
        s = f"{v:.0f}"
    elif abs(v) >= 100:
        s = f"{v:.0f}"
    elif abs(v) >= 10:
        s = f"{v:.1f}"
    elif abs(v) >= 0.1:
        s = f"{v:.2f}"
    else:
        s = f"{v:.4f}"
    return s.replace(".", dec)


def save_spec(p, r, stem, to_info=None, title=""):
    """[v17b] spec table -> CSV (Excel, German: ';' and decimal comma),
    XLSX (if openpyxl is available) and a PNG sheet. Overwritten every run."""
    rows = spec_rows(p, r, to_info)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    with open(stem + ".csv", "w", newline="", encoding="utf-8-sig") as f:
        wr = csv.writer(f, delimiter=";")
        wr.writerow(["group", "quantity", "value", "unit"])
        for g, k, v, u in rows:
            wr.writerow([g, k, _fmt(v, ","), u])
        wr.writerow(["run", "generated", stamp, ""])
    try:
        import openpyxl
        from openpyxl.styles import Font
        wb = openpyxl.Workbook(); ws = wb.active; ws.title = "spec"
        ws.append(["group", "quantity", "value", "unit"])
        for c in ws[1]:
            c.font = Font(bold=True)
        for g, k, v, u in rows:
            ws.append([g, k, v if isinstance(v, str) else float(v), u])
        ws.append(["run", "generated", stamp, ""])
        for col, wdt in zip("ABCD", (28, 44, 16, 12)):
            ws.column_dimensions[col].width = wdt
        wb.save(stem + ".xlsx")
    except ImportError:
        pass
    # PNG: two table columns side by side
    half = (len(rows) + 1) // 2
    fig, axs = plt.subplots(1, 2, figsize=(18, 0.29 * half + 1.6))
    for ax, chunk in zip(axs, (rows[:half], rows[half:])):
        ax.axis("off")
        cells = [[g, k, _fmt(v, "."), u] for g, k, v, u in chunk]
        tb = ax.table(cellText=cells, colLabels=["group", "quantity", "value", "unit"],
                      colWidths=[0.24, 0.46, 0.17, 0.13], loc="upper center", cellLoc="left")
        tb.auto_set_font_size(False); tb.set_fontsize(8.5); tb.scale(1, 1.25)
        for (i, j), c in tb.get_celld().items():
            if i == 0:
                c.set_text_props(weight="bold"); c.set_facecolor("#d9e2f3")
            elif j == 2 and chunk[i - 1][0].startswith("Constraint"):
                c.set_facecolor("#d9f2d9" if chunk[i - 1][2] >= 0 else "#f8d0d0")
    fig.suptitle(f"{title}   ({stamp})", fontsize=12)
    fig.tight_layout(); fig.savefig(stem + ".png", dpi=130); plt.close(fig)
    return rows


def plot_takeoff_history(H, p, ac, fname, law=None, v1=None, title=""):
    """[v17b] take-off time history of the design case (all engines operating):
    lift share wing / lift rotors, rate of climb, ground speed and height
    over time since brake release (left) and distance over ground (right)."""
    t, x, h, u, w = H["t"], H["x"], H["h"], H["u"], H["w"]
    L, Tv = np.maximum(H["L"], 0.0), np.maximum(H["Tv"], 0.0)
    tot = L + Tv
    with np.errstate(invalid="ignore", divide="ignore"):
        sh_w = np.where(tot > 1.0, 100 * L / tot, np.nan)
        sh_r = np.where(tot > 1.0, 100 * Tv / tot, np.nan)
    W = ac["W"]
    # events
    ev = []
    i_lo = int(np.argmax(h > 0.05)) if (h > 0.05).any() else None
    if i_lo is not None:
        ev.append((i_lo, "lift-off", "tab:gray"))
    if law is not None:
        V_cs = law[1]
        if (u >= V_cs).any():
            ev.append((int(np.argmax(u >= V_cs)), f"climb start {V_cs / KT:.0f} kt", "tab:purple"))
    if v1 is not None:
        ev.append((int(np.argmin(abs(t - v1["t"]))), f"V1 {v1['u'] / KT:.0f} kt", "k"))
    if (x >= REQ.s_field).any():
        ev.append((int(np.argmax(x >= REQ.s_field)), "300 ft", "tab:red"))
    late = np.arange(len(t)) > 20
    if ((Tv <= 1.0) & late).any():
        ev.append((int(np.argmax((Tv <= 1.0) & late)), "rotors off (wing-borne)", "tab:green"))

    # x range: take-off until the rotors are off (wing-borne) + 40 %, i.e. the
    # transition itself; the later wing-only acceleration to V_end is cut
    i_off = max((i for i, lab, c in ev if lab.startswith("rotors off")), default=len(t) - 1)
    i_end = int(min(len(t) - 1, np.searchsorted(t, 1.4 * t[i_off])))
    fig, axs = plt.subplots(4, 2, figsize=(16, 14), sharex="col")
    for col, (X, xlab) in enumerate(((t, "time since brake release [s]"),
                                     (x, "distance over ground [m]"))):
        a = axs[0, col]
        a.stackplot(X, np.nan_to_num(sh_w), np.nan_to_num(sh_r), colors=["tab:blue", "tab:orange"],
                    alpha=0.55, labels=["wing lift", "lift rotors (vertical thrust)"])
        a.plot(X, 100 * tot / W, "k--", lw=1, label="(wing + rotors) / weight")
        a.set_ylim(0, 120); a.set_ylabel("share of lift [%]")
        a.legend(fontsize=8, loc="center right")
        a = axs[1, col]
        a.plot(X, w, "tab:red", lw=1.8)
        a.set_ylabel("rate of climb [m/s]")
        s2 = a.secondary_yaxis("right", functions=(lambda v: v / (FT / 60), lambda v: v * FT / 60))
        s2.set_ylabel("[ft/min]")
        a = axs[2, col]
        a.plot(X, u / KT, "tab:green", lw=1.8)
        a.set_ylabel("ground speed [kt]")
        s2 = a.secondary_yaxis("right", functions=(lambda v: v * KT, lambda v: v / KT))
        s2.set_ylabel("[m/s]")
        a = axs[3, col]
        a.plot(X, h / FT, "k", lw=1.8)
        a.axhline(REQ.h_obs / FT, color="tab:red", lw=0.8, ls=":")
        a.set_ylabel("height [ft]")
        s2 = a.secondary_yaxis("right", functions=(lambda v: v * FT, lambda v: v / FT))
        s2.set_ylabel("[m]")
        a.set_xlabel(xlab)
        if col == 1:
            a.plot([REQ.s_field], [REQ.h_obs / FT], "rv", ms=9)
            a.annotate("50 ft obstacle at 300 ft", (REQ.s_field, REQ.h_obs / FT), xytext=(8, -14),
                       textcoords="offset points", color="tab:red", fontsize=8)
            s3 = axs[0, 1].secondary_xaxis("top", functions=(lambda v: v / FT, lambda v: v * FT))
            s3.set_xlabel("distance over ground [ft]")
        for n_ev, (i, lab, c) in enumerate(sorted(ev)):
            for rr in range(4):
                axs[rr, col].axvline(X[i], color=c, lw=0.9, ls="--", alpha=0.8)
            axs[3, col].text(X[i], 0.97 - 0.09 * (n_ev % 5), " " + lab, fontsize=7.5, color=c,
                             transform=axs[3, col].get_xaxis_transform(), va="top",
                             bbox=dict(fc="white", ec="none", alpha=0.7, pad=0.5))
        for rr, Y in ((1, w), (2, u / KT), (3, h / FT)):     # y range of the shown part
            lo_, hi_ = float(np.min(Y[:i_end + 1])), float(np.max(Y[:i_end + 1]))
            pad = 0.08 * max(hi_ - lo_, 1e-3)
            axs[rr, col].set_ylim(min(lo_ - pad, 0.0), hi_ + pad)
        for rr in range(4):
            axs[rr, col].grid(alpha=0.3)
            axs[rr, col].set_xlim(0, X[i_end])
    fig.suptitle(title or "Take-off time history (all engines operating, take-off flap setting)", fontsize=13)
    fig.tight_layout(); fig.savefig(fname, dpi=130); plt.close(fig)


H_MAX_UNPRESS = 12500 * FT                 # [v14] crew without supplemental oxygen


def compare_plot(res, fname):
    labs = list(res)
    fig, ax = plt.subplots(1, 3, figsize=(16, 5))
    x = np.arange(len(labs))
    ax[0].bar(x, [res[k]["r"]["mtow"] for k in labs], color=["tab:blue", "tab:orange"])
    ax[0].set_xticks(x); ax[0].set_xticklabels([VARIANTS[k]["label"] for k in labs], fontsize=8)
    ax[0].set_ylabel("MTOW [kg]"); ax[0].axhline(REQ.mtow_max, color="r", lw=0.8)
    for i, k in enumerate(labs):
        ax[0].text(i, res[k]["r"]["mtow"] + 30, f"{res[k]['r']['mtow']:.0f}", ha="center")
    w = 0.35
    e400 = [res[k]["r"]["E_prim"] / 3.6e6 for k in labs]
    e200 = [res[k]["t200"]["E"] / 3.6e6 if res[k]["t200"] else np.nan for k in labs]
    ax[1].bar(x - w / 2, e400, w, label="400 nmi design mission (primary energy)")
    ax[1].bar(x + w / 2, e200, w, label="200 nmi all-electric (battery energy)")
    ax[1].set_xticks(x); ax[1].set_xticklabels(labs); ax[1].set_ylabel("kWh per flight"); ax[1].legend(fontsize=8)
    t400 = [res[k]["r"]["t_block"] * 60 for k in labs]
    t200 = [res[k]["t200"]["t_block"] * 60 if res[k]["t200"] else np.nan for k in labs]
    ax[2].bar(x - w / 2, t400, w, label="400 nmi"); ax[2].bar(x + w / 2, t200, w, label="200 nmi")
    ax[2].set_xticks(x); ax[2].set_xticklabels(labs); ax[2].set_ylabel("block time [min]"); ax[2].legend(fontsize=8)
    fig.suptitle("Pressurised (P) vs unpressurised (U) variant"); fig.tight_layout()
    fig.savefig(fname, dpi=130); plt.close(fig)


def aux_table(p, r):
    rows = []
    for lab, h, Ps in (("ground / taxi (hot day)", 0.0, r["P_lift"]),
                       ("climb (mean altitude)", r["h_cr"] / 2, r["P_push"]),
                       ("cruise", r["h_cr"], r["P_push"] * 0.5),
                       ("descent", r["h_cr"] / 2, 0.0)):
        tot, parts = aux_power(p, h, Ps)
        rows.append((lab, h, tot, parts))
    return rows


if __name__ == "__main__":
    t0 = time.time()
    p = replace(P(), V_lof=24 * KT, f_unload=0.5, k_em_lift=1.3, lift_lanes=2,
                v_cruise=225 * KT, **HIGHLIFT["single-slotted flap"])
    best, rows = search_fast(p)
    # reference: same concept at 230 kt (v13 variant U)
    ref, _ = search_fast(replace(p, v_cruise=225 * KT))
    print(f" reference 225 kt: MTOW {ref['mtow']:.0f} kg, primary {ref['E_prim'] / 3.6e6:.0f} kWh,"
          f" block {ref['t_block'] * 60:.0f} min")
    t200 = best_electric_trip(best, p, 200.0, H_MAX_UNPRESS)
    rmax = max_electric_range(best, p, H_MAX_UNPRESS)
    print(f"\n 200 nmi all-electric: {'POSSIBLE' if t200['feasible'] else 'NOT possible'} at"
          f" {t200['h'] / FT:.0f} ft, battery {t200['E'] / 3.6e6:.0f} of {t200['usable'] / 3.6e6:.0f} kWh"
          f" ({'reserve kept' if t200['keeps_reserve'] else 'reserve used'}), block {t200['t_block'] * 60:.0f} min")
    print("   split [kWh]: " + ", ".join(f"{k} {v / 3.6e6:.0f}" for k, v in t200["split"].items()))
    print(f" max all-electric range (reserve used): {rmax:.0f} nmi")
    for lab, h, tot, parts in aux_table(p, best):
        print(f"   systems, {lab:26s}: {tot / 1e3:4.1f} kW")
   # print("\n PROFILES (best design for each value; objective MTOW + energy)")
    for k, lab in (("AR", "AR"), ("ws", "W/S"), ("D_rot", "D"), ("h_cr", "h")):
        vals = sorted({r[k] for r in rows})
        s = []
        for v in vals:
            bb = min((r for r in rows if r[k] == v), key=lambda r: r["obj"])
            s.append(f"{(v / FT if k == 'h_cr' else v):g}: {bb['mtow']:.0f} kg/{bb['E_prim'] / 3.6e6:.0f} kWh")
       # print(f"   {lab:4s} " + " | ".join(s))
    profiles(rows, OUT + "evtol_v18_2035_heliport_profiles.png",
             "Unpressurised, EIS-2035 optimistic 225 kt: effect of each design decision")
    law0 = (1.0, 30 * KT, 10.0, 30.0, True)
    res = design_takeoff3(p, best, [law0], margins=(1.05, 1.10, 1.20))
    to_H, to_law, to_v1, to_info, p_rep = None, None, None, None, p
    if res:
        km, r, pk, law, a, n = res
        ls = landing_scan(r["ac"], pk)
        print(f"\n SAFETY: rotor margin {km:.2f}, V1 = {a['v1']['u'] / KT:.0f} kt at {a['v1']['h'] / FT:.0f} ft,"
              f" take-off {a['aeo']['E'] / 3.6e6:.1f} kWh, landing {ls['L']['s'] / FT:.0f} ft,"
              f" worst failure sink {ls['worst_after_ldp']:.1f} m/s")
        best = r
        to_H, to_law, to_v1, p_rep = a["aeo"]["H"], law, a["v1"], pk
        Ha = to_H
        off = (Ha["Tv"] <= 1.0) & (np.arange(len(Ha["t"])) > 20)
        i_off = int(np.argmax(off)) if off.any() else len(Ha["t"]) - 1
        to_info = [("rotor power margin", km, "-"),
                   ("V1", a["v1"]["u"] / KT if a["v1"] else float("nan"), "kt"),
                   ("height at V1", a["v1"]["h"] / FT if a["v1"] else float("nan"), "ft"),
                   ("take-off energy (AEO)", a["aeo"]["E"] / 3.6e6, "kWh"),
                   ("height at 300 ft (AEO)", a["aeo"]["h_obs"] / FT, "ft"),
                   ("time / distance until rotors off",
                    f"{Ha['t'][i_off]:.1f} s / {Ha['x'][i_off]:.0f} m", "-"),
                   ("time / distance to 1.25 Vs clean (sim end)",
                    f"{a['aeo']['t']:.1f} s / {a['aeo']['x']:.0f} m", "-")]
    else:                                                 # fall back to the sizing take-off law
        tr = takeoff(best["ac"], p, record=True)
        to_H = {k: v for k, v in tr["hist"].items()}
    best["field_5000"] = field_case(best, p, 5000.0)
    print(f"design search {time.time() - t0:.1f} s  (EIS-2035 optimistic, cruise {p.v_cruise / KT:.0f} kt,"
          f" electric objective {REQ.range_el_cruise:.0f} nmi, altitude <= {H_MAX_UNPRESS / FT:.0f} ft, unpressurised)")
    report(p, best)
    metabook_crosschecks(p, best)
    draw_threeview(best, p, OUT + "evtol_v18_2035_heliport_threeview.png")
    save_spec(p_rep, best, OUT + "evtol_v18_2035_heliport_spec", to_info,
              f"EVTOL-SIZE v18 spec -- MTOW {best['mtow']:.0f} kg, W/S {best['ws']} N/m^2"
              f" (max {REQ.ws_max:.0f}), AR {best['AR']}, {best['v'] / KT:.0f} kt")
    plot_takeoff_history(to_H, p_rep, best["ac"], OUT + "evtol_v18_2035_heliport_takeoff.png",
                         law=to_law, v1=to_v1,
                         title=f"Take-off, MTOW {best['mtow']:.0f} kg, W/S {best['ws']} N/m^2 -- "
                               "all engines, take-off flaps (50 ft at 300 ft)")
    print(f" outputs written to {OUT}")
    print(f"\n total run time {time.time() - t0:.0f} s")
