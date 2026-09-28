# -*- coding: utf-8 -*-
"""
===============================================================================
 STOL_VTOL_SIZING  -  one sizing code, two concepts, one set of assumptions
   "BW"   blown-wing DEP STOL: n_hl high-lift props across the span (blowing
          flaps for take-off/landing) + 2 wing-tip cruise props
   "VTOL" lift + cruise: 4 lift rotors (2 motor lanes each) + 1 pusher
          (2 motor lanes on one propeller)
 Both: series hybrid (turboshaft-generator + battery -> DC bus -> e-motors),
 same mission, same technology level, same aero/structure methods.

 HARD requirements = RFP only (class RFP). Everything else = assumption (class
 Tech / Concept), all in SI units internally.

 Method (Metabook-/Raymer-/Roskam-style, conceptual level):
   1  geometry + CD0 by wetted-area build-up          Raymer Ch. 6/12
   2  installed power from constraints at the chosen W/S (cruise at 80 %
      rating, 1500 fpm, FAR 23 climb gradients, OEI, field performance)
   3  mission energy: Breguet (fuel leg, series-hybrid efficiency chain),
      electric range equation (battery leg), IFR fuel reserve
   4  empty mass build-up, MTOW fixed-point iteration
   5  grid search over W/S, AR (and rotor diameter) -> minimum MTOW
 Metabook equation numbers are those used in the v18 eVTOL code; verify them
 against your copy of the Metabook before quoting them in the report.

 Run:  python stol_vtol_sizing.py      (~10-30 s, plots in ./sizing_output)
===============================================================================
"""
from dataclasses import dataclass, replace
from pathlib import Path
import math, time
import numpy as np
_trapz = np.trapezoid if hasattr(np, "trapezoid") else np.trapz   # NumPy <2.0 compatibility
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

G, FT, KT, NMI, LB, HP, WH = 9.80665, 0.3048, 1852 / 3600, 1852.0, 0.45359237, 745.7, 3600.0
LHV = 43.0e6                                   # J/kg, Jet-A
OUT = Path(__file__).with_name("sizing_output"); OUT.mkdir(exist_ok=True)


# =============================================================================
#  RFP -- the only hard constraints
# =============================================================================
@dataclass(frozen=True)
class RFP:
    n_occ: int = 8                          # 1 pilot + 7 passengers
    m_occ: float = (190 + 30) * LB          # kg, 190 lb person + 30 lb baggage
    R_total: float = 400.0                  # nmi design mission
    V_cr_min: float = 225.0 * KT            # m/s minimum cruise speed
    s_field: float = 300.0 * FT             # take-off over 50 ft
    s_land: float = 300.0 * FT              # landing over 50 ft (both old codes assumed 300 ft -> check RFP)
    h_obs: float = 50.0 * FT
    roc_min: float = 1500.0 * FT / 60       # m/s, all engines, SL hot day
    mtow_max: float = 19000.0 * LB          # kg (19,000 lb)
    R_el_obj: float = 180.0                 # nmi all-electric range (OBJECTIVE, not hard)


REQ = RFP()


def rho_isa(h, dT=0.0):
    """ISA density with temperature offset dT [K] (troposphere)."""
    return 101325.0 * (1 - 2.25577e-5 * h) ** 5.25588 / (287.053 * (288.15 - 0.0065 * h + dT))


# =============================================================================
#  COMMON ASSUMPTIONS (identical for both concepts)
# =============================================================================
@dataclass
class Tech:
    # operating point
    V_cr: float = 225.0 * KT                # RFP minimum
    h_cr: float = 12000.0 * FT              # unpressurised
    h_field: float = 0.0                    # design field altitude
    dT_field: float = 10.0                  # K, ISA+18 degF hot day (check RFP)
    v_climb: float = 150.0 * KT
    # battery (pack level)
    e_pack: float = 420.0 * WH              # J/kg
    f_usable: float = 0.90                  # usable share (DoD / end-of-life)
    p_pack: float = 2.2e3                   # W/kg peak discharge
    # efficiencies
    eta_batt: float = 0.97
    eta_cable: float = 0.997
    eta_inv: float = 0.995
    eta_mot: float = 0.97
    eta_gen: float = 0.98
    eta_prop: float = 0.85                  # cruise propeller
    FM: float = 0.82                        # static figure of merit (rotors and props)
    # turboshaft
    sfc: float = 0.40 * LB / (HP * 3600)    # kg/J  (0.40 lb/hp/h, optimistic)
    n_lapse: float = 0.75                   # P ~ sigma^n
    f_rating: float = 0.80                  # cruise at <= 80 % rated power (Metabook Eq. 4.41)
    # specific power (2035, optimistic) W/kg
    sp_mot: float = 8.0e3
    sp_inv: float = 20.0e3
    sp_gen: float = 12.0e3
    sp_ts: float = 5.0e3
    f_cool: float = 0.10                    # thermal management, share of machine mass
    m_HV: float = 70.0                      # kg HV distribution, BMS, battery TMS (v18 list)
    P_aux: float = 3.0e3                    # W non-propulsive electric load
    k_em: float = 1.20                      # OEI emergency rating, cruise/pusher motors
    k_em_short: float = 1.30                # 30-s rating, lift / high-lift motors
    # aerodynamics (Metabook Table 4.2 = Roskam Part I Tab. 3.6, mid values)
    Cfe: float = 0.0040                     # equivalent skin friction (Raymer Tab. 12.3 range)
    e_clean: float = 0.825
    CLmax_clean: float = 1.60
    dCL_flap_LDG: float = 1.0               # single-slotted flap, landing
    dCL_flap_TO: float = 0.65               # take-off setting
    dCD0_TO: float = 0.015; e_TO: float = 0.775
    dCD0_LDG: float = 0.065; e_LDG: float = 0.725
    dCD0_gear: float = 0.020
    dCL_climb: float = 0.20                 # climb at CL <= CLmax - 0.2 (Metabook 4.7.2)
    # structure: airframe (fuselage, tails, gear, all-else) method
    #   "raymer_ga": Raymer Tab. 15.2 GA column build-up, Tab. 15.4 composite factors
    #   "v18":       v18 regression (0.92 W0^-0.05 - 0.23) W0 * 1.03 * 0.9 + 120 kg systems
    airframe: str = "raymer_ga"
    k_v18_struct: float = 1.03; k_v18_airframe: float = 0.90; m_sys_v18: float = 120.0
    t_c: float = 0.14; taper: float = 0.6; f_csw: float = 0.30
    k_wing: float = 0.85; k_fus: float = 0.92; k_tail: float = 0.85; k_gear: float = 0.95
    rho_fus: float = 7.0                    # kg/m^2 fuselage wetted area
    rho_tail: float = 10.0                  # kg/m^2 tail planform area
    f_gear: float = 0.057                   # of MTOW
    f_else: float = 0.10                    # all-else empty (avionics, furnishing, systems)
    k_prop: float = 6.66                    # kg/m^2 propeller mass ~ D^2 (45 kg @ 2.6 m)
    # mission / reserves
    R_alt: float = 50.0                     # nmi alternate (14 CFR 135.223(a)(2))
    t_res: float = 45.0 * 60                # s at cruise speed (14 CFR 135.223(a)(3))
    f_trapped: float = 0.01                 # trapped fuel
    E_taxi: float = 3.0e3 * WH              # J battery for taxi
    h_desc_end: float = 1500.0 * FT
    # field performance
    mu_roll: float = 0.03; mu_brake: float = 0.45; f_rev: float = 0.30
    t_rot: float = 1.0; t_free: float = 1.0; n_flare: float = 1.2
    electric_objective: bool = True         # size battery for the 200 nmi all-electric objective


@dataclass
class Concept:
    kind: str = "BW"                        # "BW" or "VTOL"
    # --- blown wing
    n_hl: int = 8                           # high-lift props (MATLAB file: 6)
    f_blown: float = 0.80                   # blown share of the span outside the fuselage
    CLmax_bl: float = 9.0                   # blown CLmax (design variable in the search, <= CLmax_bl_max)
    CLmax_bl_max: float = 9.0               # upper limit allowed for the blown CLmax
    k_blow: float = 1.0                     # 1 = ideal slipstream dynamic-pressure model
    CL_ground: float = 1.0                  # ground-roll CL with blowing
    gamma_app: float = 12.0                 # deg, max approach path angle
    gamma_TO_max: float = 20.0              # deg, max climb angle after lift-off
    delta_j_LD: float = 60.0                # deg, effective slipstream turning, landing flaps
    delta_j_TO: float = 15.0                # deg, effective slipstream turning, take-off flaps
    hl_in_climb: bool = True                # HL props run in climb (fold only in cruise)
    n_cr_props: int = 2                     # wing-tip cruise props, 1 motor each
    D_cr: float = 2.0                       # m
    m_hl_nac: float = 3.0                   # kg per HL nacelle + folding mechanism
    # --- lift + cruise
    n_rot: int = 4; lanes: int = 2; D_rot: float = 4.0
    k_download: float = 1.05; vz_TO: float = 2.5
    t_hover: float = 10.0                   # s hover margin per take-off / landing
    a_tr: float = 1.5                       # m/s^2 mean acceleration in the transition
    m_rotor4: float = 25.0; m_boom: float = 30.0   # kg (rotor @ D = 4 m, per boom)
    f_rot_stop: float = 0.02                # m^2 drag area per stopped rotor (@ 4 m)
    D_push: float = 2.6
    # --- optional heliport / vertiport (FAA EB 105A reference envelope)
    heliport: bool = False
    heli_mtow: float = 5670.0               # kg (12,500 lb)
    heli_D: float = 15.2                    # m controlling dimension


# =============================================================================
#  helpers: efficiencies, propeller thrust, polar
# =============================================================================
def eta_bus(t):             # DC bus -> shaft
    return t.eta_cable * t.eta_inv * t.eta_mot


def eta_batt_thrust(t):     # battery -> thrust power (range equation)
    return t.eta_batt * eta_bus(t) * t.eta_prop


def eta_fuel_thrust(t):     # fuel -> turboshaft -> generator -> bus -> prop
    eta_th = 1.0 / (t.sfc * LHV)
    return eta_th * t.eta_gen * eta_bus(t) * t.eta_prop


def prop_thrust(P, V, A, rho, t):
    """Thrust of an actuator disk (area A) from shaft power P at speed V:
    momentum theory with FM, limited by eta_prop*P/V at speed (Leishman)."""
    if P <= 0:
        return 0.0
    T = (t.FM * P) ** (2 / 3) * (2 * rho * A) ** (1 / 3)
    for _ in range(8):                              # Newton, converges in ~4 steps
        s = math.sqrt(V * V / 4 + T / (2 * rho * A))
        T -= (T * (V / 2 + s) - t.FM * P) / (V / 2 + s + T / (4 * rho * A * s))
    return min(T, t.eta_prop * P / V) if V > 1.0 else T


def polar(ac, t, cfg, gear):
    """(CD0, K) for 'clean', 'TO' or 'LDG' (Metabook Table 4.2)."""
    if cfg == "clean":
        return ac["CD0"], 1 / (math.pi * ac["AR"] * t.e_clean)
    dCD, e = (t.dCD0_TO, t.e_TO) if cfg == "TO" else (t.dCD0_LDG, t.e_LDG)
    return ac["CD0"] + dCD + (t.dCD0_gear if gear else 0.0), 1 / (math.pi * ac["AR"] * e)


def CL_limit(t, cfg):
    dCL = {"clean": 0.0, "TO": t.dCL_flap_TO, "LDG": t.dCL_flap_LDG}[cfg]
    return t.CLmax_clean + dCL


# =============================================================================
#  1  GEOMETRY + DRAG  (same method for both)
# =============================================================================
def geometry(c, t, m0, ws, AR):
    W = m0 * G; S = W / ws; b = math.sqrt(AR * S); cbar = S / b
    L = 0.169 * m0 ** 0.51                           # Raymer Tab. 6.3, twin turboprop (metric)
    d = math.sqrt(1.6 * 1.8); fr = L / d
    Sw_fus = math.pi * d * L * (1 - 2 / fr) ** (2 / 3) * (1 + 1 / fr ** 2)   # Torenbeek
    l_t = 0.5 * L
    S_ht, S_vt = 0.90 * cbar * S / l_t, 0.08 * b * S / l_t   # Raymer Tab. 6.4 (c_HT, c_VT)
    Sw = Sw_fus + 2.05 * (S - 1.6 * cbar) + 2.03 * (S_ht + S_vt)
    f_extra = 0.0                                    # m^2 drag area not in Sw*Cfe
    ac = dict(W=W, m0=m0, S=S, b=b, c=cbar, AR=AR, L=L, Sw_fus=Sw_fus, S_ht=S_ht, S_vt=S_vt,
              rho=rho_isa(t.h_field, t.dT_field))
    if c.kind == "BW":
        D_hl = c.f_blown * (b - 1.6) / c.n_hl        # props side by side over the blown span
        Sw += c.n_hl * math.pi * 0.25 * 0.8 + c.n_cr_props * math.pi * 0.45 * 1.6   # nacelles
        ac.update(D_hl=D_hl, A_hl=c.n_hl * math.pi * D_hl ** 2 / 4,
                  A_cr=c.n_cr_props * math.pi * c.D_cr ** 2 / 4, ctrl_D=max(b, L))
    else:
        y_boom = 0.8 + c.D_rot / 2 + 0.3
        l_boom = c.D_rot + 0.6 + cbar
        Sw += 2 * math.pi * 0.3 * l_boom
        f_extra = c.n_rot * c.f_rot_stop * (c.D_rot / 4) ** 2
        rd = 2 * (math.hypot(y_boom, l_boom / 2) + c.D_rot / 2)     # rotor enclosing circle
        ac.update(A_rot=c.n_rot * math.pi * c.D_rot ** 2 / 4, A_cr=math.pi * c.D_push ** 2 / 4,
                  y_boom=y_boom, l_boom=l_boom, RD=rd, ctrl_D=max(b, L, rd))
    ac["CD0"] = t.Cfe * Sw / S + f_extra / S
    ac["K"] = 1 / (math.pi * AR * t.e_clean)
    ac["LDmax"] = 0.5 / math.sqrt(ac["CD0"] * ac["K"])
    return ac


def LD(ac, W, V, h):
    q = 0.5 * rho_isa(h) * V * V
    CL = W / (q * ac["S"])
    return CL / (ac["CD0"] + ac["K"] * CL * CL), CL


# =============================================================================
#  2a  CRUISE-PROPULSOR POWER (tip props or pusher, 2 motors in both cases)
# =============================================================================
def climb_power(ac, t, W, grad, cfg, gear, rho, roc=0.0):
    """Min shaft power for a climb gradient (or ROC) in a configuration, best
    speed with CL <= CLmax - 0.2 (Metabook Sec. 4.7.2)."""
    CD0, K = polar(ac, t, cfg, gear)
    CLl = CL_limit(t, cfg) - t.dCL_climb
    best = 1e12
    for V in np.linspace(25, 120, 40):
        q = 0.5 * rho * V * V
        CL = W / (q * ac["S"])
        if CL > CLl:
            continue
        T = q * ac["S"] * (CD0 + K * CL * CL) + W * (grad + roc / V)
        P = max(T * V / t.eta_prop,
                T * (V / 2 + math.sqrt(V * V / 4 + T / (2 * rho * ac["A_cr"]))) / t.FM)
        best = min(best, P)
    return best


def cruise_prop_power(ac, t, W, ld_cr, A_extra=0.0):
    rho0 = ac["rho"]
    ac = dict(ac, A_cr=ac["A_cr"] + A_extra)        # disk area available in climb
    req = dict(
        cruise=W * t.V_cr / ld_cr / t.eta_prop / t.f_rating,                      # Eq. 4.41
        ROC_1500=climb_power(ac, t, W, 0.0, "clean", False, rho0, REQ.roc_min),   # RFP
        FAR23_2120a=climb_power(ac, t, W, 0.04, "TO", True, rho0),                # AEO 4 %
        FAR23_2120c=climb_power(ac, t, W, 0.03, "LDG", True, rho0),               # balked 3 %
        FAR23_2120b=2 * climb_power(ac, t, W, 0.01, "TO", False, rho0) / t.k_em,  # OEI 1 %
    )
    return max(req.values()), req


# =============================================================================
#  2b  BLOWN WING: blowing power, take-off and landing distance
# =============================================================================
def blow_ratio2(c, CL_target, CL_flap):
    """(V_w/V)^2 needed so that the blown share of the span reaches CL_target:
    CL = CL_flap*[(1-f) + f*(1 + k*((Vw/V)^2-1))]  (slipstream dynamic pressure)."""
    return 1 + max(CL_target / CL_flap - 1, 0.0) / (c.f_blown * c.k_blow)


def blow_thrust_power(ac, t, V, r2, rho):
    """HL-prop thrust and power that give slipstream ratio sqrt(r2) at speed V
    (actuator disk, fully developed slipstream V_w = V + 2 v_i)."""
    vi = V * (math.sqrt(r2) - 1) / 2
    T = 2 * rho * ac["A_hl"] * vi * (V + vi)
    return T, T * (V + vi) / t.FM


def bw_takeoff(ac, c, t, P_hl, P_cr, rho=None):
    """Ground roll (numerical, s = int m V dV / F), rotation, Raymer 17.8
    transition arc (n = 1.2) and climb to 50 ft. Blown CLmax = c.CLmax_bl."""
    rho = ac["rho"] if rho is None else rho
    W, S = ac["W"], ac["S"]; m = W / G
    Vs = math.sqrt(2 * W / (rho * S * c.CLmax_bl))
    V_LO, V_TR = 1.1 * Vs, 1.15 * Vs                  # Metabook Sec. 4.4 / Raymer
    CD0, K = polar(ac, t, "TO", True)
    V = np.linspace(0.0, V_LO, 25)
    cj = math.cos(math.radians(c.delta_j_TO))        # turned slipstream: axial share
    T = np.array([cj * prop_thrust(P_hl, v, ac["A_hl"], rho, t) + prop_thrust(P_cr, v, ac["A_cr"], rho, t) for v in V])
    q = 0.5 * rho * V * V
    F = T - q * S * (CD0 + K * c.CL_ground ** 2) - t.mu_roll * np.maximum(W - q * S * c.CL_ground, 0)
    if F.min() <= 0:
        return math.inf, None
    s_G = _trapz(m * V / F, V); t_G = _trapz(m / F, V)
    CL_TR = c.CLmax_bl / 1.15 ** 2
    Tt = cj * prop_thrust(P_hl, V_TR, ac["A_hl"], rho, t) + prop_thrust(P_cr, V_TR, ac["A_cr"], rho, t)
    D = 0.5 * rho * V_TR ** 2 * S * (CD0 + K * CL_TR ** 2)
    sg = (Tt - D) / W
    if sg <= 0:
        return math.inf, None
    gam = min(math.asin(min(sg, 0.9)), math.radians(c.gamma_TO_max))
    R = V_TR ** 2 / (G * (t.n_flare - 1))
    h_TR = R * (1 - math.cos(gam))
    if h_TR >= REQ.h_obs:
        s_A = math.sqrt(R * R - (R - REQ.h_obs) ** 2)
    else:
        s_A = R * math.sin(gam) + (REQ.h_obs - h_TR) / math.tan(gam)
    s = s_G + V_LO * t.t_rot + s_A
    return s, dict(s_G=s_G, s_A=s_A, V_LO=V_LO, gamma=math.degrees(gam),
                   t=t_G + t.t_rot + s_A / V_TR)


def bw_landing(ac, c, t, P_cr, rho=None):
    """Powered approach at 1.3 Vs (blown), path angle limited by D - T_blow,
    Raymer 17.9 flare (n = 1.2), free roll, brakes + reverse thrust."""
    rho = ac["rho"] if rho is None else rho
    W, S = ac["W"], ac["S"]; m = W / G
    Vs = math.sqrt(2 * W / (rho * S * c.CLmax_bl))
    Va, Vf, Vtd = 1.3 * Vs, 1.23 * Vs, 1.15 * Vs
    r2 = blow_ratio2(c, c.CLmax_bl, CL_limit(t, "LDG"))
    T_bl, P_bl = blow_thrust_power(ac, t, Va, r2, rho)
    CD0, K = polar(ac, t, "LDG", True)
    CLa = c.CLmax_bl / 1.3 ** 2
    D = 0.5 * rho * Va ** 2 * S * (CD0 + K * CLa ** 2)
    sg = (D - T_bl * math.cos(math.radians(c.delta_j_LD))) / W   # turned slipstream
    if sg <= 0.0:
        return math.inf, dict(gamma=0.0, P_bl=P_bl, Va=Va)
    gam = min(math.asin(min(sg, 0.9)), math.radians(c.gamma_app))
    R = Vf ** 2 / (G * (t.n_flare - 1))
    h_f = R * (1 - math.cos(gam))
    if h_f >= REQ.h_obs:
        s_A = math.sqrt(R * R - (R - REQ.h_obs) ** 2)
    else:
        s_A = (REQ.h_obs - h_f) / math.tan(gam) + R * math.sin(gam)
    a_b = t.mu_brake * G + t.f_rev * prop_thrust(P_cr, 0.0, ac["A_cr"], rho, t) / m
    s = s_A + Vtd * t.t_free + Vtd ** 2 / (2 * a_b)
    return s, dict(gamma=math.degrees(gam), P_bl=P_bl, Va=Va, t_app=500 * FT / (Va * math.sin(gam)))


def bw_power(ac, c, t, P_cr):
    """High-lift power: blowing requirement (take-off and approach), then the
    smallest power that gives 50 ft at 300 ft (bisection)."""
    rho, W, S = ac["rho"], ac["W"], ac["S"]
    Vs = math.sqrt(2 * W / (rho * S * c.CLmax_bl))
    P_blow_TO = blow_thrust_power(ac, t, 1.1 * Vs, blow_ratio2(c, c.CLmax_bl, CL_limit(t, "TO")), rho)[1]
    P_blow_LD = blow_thrust_power(ac, t, 1.3 * Vs, blow_ratio2(c, c.CLmax_bl, CL_limit(t, "LDG")), rho)[1]
    lo = max(P_blow_TO, P_blow_LD)
    if bw_takeoff(ac, c, t, lo, P_cr)[0] <= REQ.s_field:
        return lo, dict(P_blow_TO=P_blow_TO, P_blow_LD=P_blow_LD)
    hi = 4 * lo + 0.3 * W                       # upper bound ~ 0.3 W/N extra
    if bw_takeoff(ac, c, t, hi, P_cr)[0] > REQ.s_field:
        return hi, dict(P_blow_TO=P_blow_TO, P_blow_LD=P_blow_LD)   # 300 ft not reachable -> flagged
    for _ in range(14):                         # 1/16000 of the bracket
        mid = 0.5 * (lo + hi)
        lo, hi = (lo, mid) if bw_takeoff(ac, c, t, mid, P_cr)[0] <= REQ.s_field else (mid, hi)
    return hi, dict(P_blow_TO=P_blow_TO, P_blow_LD=P_blow_LD)


# =============================================================================
#  2c  LIFT + CRUISE: lift-rotor power (hover, climb, one lane out)
# =============================================================================
def hover_power(T, A, rho, t):
    return T * math.sqrt(T / (2 * rho * A)) / t.FM


def vtol_lift_power(ac, c, t, rho=None):
    rho = ac["rho"] if rho is None else rho
    T = c.k_download * ac["W"]
    Ph = hover_power(T, ac["A_rot"], rho, t)
    vh = math.sqrt(T / (2 * rho * ac["A_rot"]))
    x = c.vz_TO / (2 * vh)
    P_climb = Ph * (x + math.sqrt(x * x + 1))          # axial climb, momentum theory
    # equivalent full-hover time of one take-off: vertical climb to 50 ft + 5 m,
    # hover margin, transition 0 -> 1.2 Vs at a_tr with rotor thrust W(1-(V/Vw)^2),
    # P ~ T^1.5  ->  mean power share int_0^1 (1-x^2)^1.5 dx = 3*pi/16
    Vw = 1.2 * math.sqrt(2 * ac["W"] / (rho * ac["S"] * CL_limit(t, "TO")))
    t_eq = (REQ.h_obs + 5.0) / c.vz_TO + c.t_hover + 3 * math.pi / 16 * Vw / c.a_tr
    # one motor lane of one rotor lost; quad trim forces the diagonal partner
    # to the same thrust -> 2 rotors at (1/2)^(2/3) of their max thrust
    f_lane = ((c.lanes - 1) / c.lanes) ** (2 / 3)
    cap = (c.n_rot - 2 + 2 * f_lane) / c.n_rot
    P_oei = Ph * cap ** -1.5 / t.k_em_short
    return max(P_climb, P_oei), dict(hover=Ph, climb=P_climb, OEI_lane=P_oei, t_eq=t_eq, V_wing=Vw)


# =============================================================================
#  3+4  SIZING LOOP (mission energy + mass build-up)
# =============================================================================
def load_factor(t, W, S, AR, V, h):
    """Limit manoeuvre n (FAR 23 formula, Metabook Eq. 11.3) and Pratt gust
    n at V_C (Metabook Eq. 11.4-11.5), n_ult = 1.5 max."""
    W_lb = W / G / LB
    n_man = min(2.1 + 24000.0 / (W_lb + 10000.0), 3.8)
    rho = rho_isa(h)
    a = 2 * math.pi * AR / (2 + math.sqrt(AR ** 2 + 4))       # DATCOM, M ~ 0.35 neglected
    mu = 2 * (W / S) / (rho * math.sqrt(S / AR) * a * G)
    Kg = 0.88 * mu / (5.3 + mu)
    ws_psf = (W / S) * FT ** 2 / (LB * G)
    V_EAS_kt = V * math.sqrt(rho / 1.225) / KT
    n_gust = 1 + Kg * a * 50.0 * V_EAS_kt / (498.0 * ws_psf)  # Ue = 50 ft/s at V_C
    return n_man, n_gust, 1.5 * max(n_man, n_gust)


def wing_mass(t, W, S, AR, n_ult):
    """Raymer Eq. 15.25 (Metabook Eq. 7.11), unswept, x composite factor."""
    Wlb, Sft = W / G / LB, S / FT ** 2
    m_lb = (0.0051 * (Wlb * n_ult) ** 0.557 * Sft ** 0.649 * AR ** 0.5 * t.t_c ** -0.4
            * (1 + t.taper) ** 0.1 * (t.f_csw * Sft) ** 0.1)
    return m_lb * LB * t.k_wing


def size(c, t, ws, AR, m0=5000.0, verbose=False):
    V, h = t.V_cr, t.h_cr
    m_pay = REQ.n_occ * REQ.m_occ
    W_fuel_burn = 0.05 * m0 * G                     # first guess (weight at electric leg)
    P_hl_prev = 0.0
    for it in range(300):
        ac = geometry(c, t, m0, ws, AR)
        W, S = ac["W"], ac["S"]
        # ---- aero
        ld_cr, CL_cr = LD(ac, 0.97 * W, V, h)
        ld_cl, _ = LD(ac, W, t.v_climb, h / 2)
        # ---- installed power
        if c.kind == "BW" and c.hl_in_climb:
            P_cr, P_cr_req = cruise_prop_power(ac, t, W, ld_cr, A_extra=ac["A_hl"])
            clb = max(P_cr_req[k] for k in ("ROC_1500", "FAR23_2120a", "FAR23_2120c"))
            P_cr = max(P_cr_req["cruise"], P_cr_req["FAR23_2120b"], clb - P_hl_prev)
        else:
            P_cr, P_cr_req = cruise_prop_power(ac, t, W, ld_cr)
        if c.kind == "BW":
            P_hl, bwi = bw_power(ac, c, t, P_cr)
            s_TO, toi = bw_takeoff(ac, c, t, P_hl, P_cr)
            s_LD, ldi = bw_landing(ac, c, t, P_cr)
            if toi is None:
                return None
            P_hl_prev = P_hl
            s_LD = min(s_LD, 1e4)
            P_lift = P_hl
            P_peak = (P_hl + P_cr) / eta_bus(t)
            E_TO = P_peak * (toi["t"] + 20.0)                         # + 20 s flap clean-up
            E_LD = ldi["P_bl"] / eta_bus(t) * min(ldi.get("t_app", 60.0), 120.0)
        else:
            P_lift, liftinfo = vtol_lift_power(ac, c, t)
            s_TO = s_LD = 0.0                                          # vertical
            P_peak = (P_lift + 0.5 * P_cr) / eta_bus(t)
            E_TO = E_LD = liftinfo["hover"] / eta_bus(t) * liftinfo["t_eq"]
        # ---- genset: cruise at altitude, <= 80 % rating
        lapse_cr = (rho_isa(h) / 1.225) ** t.n_lapse
        P_bus_cr = 0.97 * W * V / (ld_cr * t.eta_prop * eta_bus(t)) + t.P_aux
        P_ts = P_bus_cr / t.eta_gen / lapse_cr / t.f_rating              # SL rated shaft
        # ---- mission (series hybrid)
        t_cl = h / REQ.roc_min; s_cl = t.v_climb * t_cl / NMI
        P_cl_bus = W * (t.v_climb / ld_cl + REQ.roc_min) / (t.eta_prop * eta_bus(t)) + t.P_aux
        P_gen_cl = min(P_cl_bus, P_ts * t.eta_gen * (rho_isa(h / 2) / 1.225) ** t.n_lapse)
        E_cl_batt = (P_cl_bus - P_gen_cl) * t_cl / t.eta_batt              # battery assist
        fuel_cl = P_gen_cl / t.eta_gen * t.sfc * t_cl
        ld_de, _ = LD(ac, 0.9 * W, V, h)
        s_de = (h - t.h_desc_end) * ld_de / NMI                             # glide, no energy
        E_fix = (E_TO + E_LD) / t.eta_batt + t.E_taxi
        # battery: electric objective or minimum (power / fixed energies)
        e_m = lambda Wx: Wx / (ld_cr * eta_batt_thrust(t)) + t.P_aux / (V * t.eta_batt)   # J/m
        W_el = W - W_fuel_burn
        if t.electric_objective:
            E_cl_full = P_cl_bus * t_cl / t.eta_batt
            R_cr_obj = max(REQ.R_el_obj - s_cl - s_de, 0.0) * NMI
            E_bat = E_fix + E_cl_full + e_m(W_el) * R_cr_obj
        else:
            E_bat = E_fix + E_cl_batt
        m_bE = E_bat / (t.e_pack * t.f_usable)
        m_bP = max(P_peak - P_ts * t.eta_gen, 0.0) / t.p_pack
        m_bat = max(m_bE, m_bP)
        E_use = m_bat * t.e_pack * t.f_usable
        R_el = max(E_use - E_fix - E_cl_batt, 0.0) / e_m(W_el) / NMI        # electric cruise
        R_fuel = max(REQ.R_total - s_cl - s_de - R_el, 0.0)
        R_el = REQ.R_total - s_cl - s_de - R_fuel if R_fuel > 0 else R_el
        eta_f = eta_fuel_thrust(t)
        W1 = W - fuel_cl * G
        W2 = W1 * math.exp(-R_fuel * NMI * G / (eta_f * LHV * ld_cr))      # Breguet
        fuel_mis = fuel_cl + (W1 - W2) / G + t.P_aux / (t.eta_gen) * t.sfc * R_fuel * NMI / V
        W_fuel_burn = fuel_mis * G
        # IFR reserve on fuel: alternate + 45 min at cruise speed
        R_res = t.R_alt * NMI + V * t.t_res
        W_end = W - fuel_mis * G
        fuel_res = W_end / G * (math.exp(R_res * G / (eta_f * LHV * ld_cr)) - 1)
        fuel = (fuel_mis + fuel_res) * (1 + t.f_trapped)
        # ---- masses
        n_man, n_gust, n_ult = load_factor(t, W, S, AR, V, h)
        m_wing = wing_mass(t, W, S, AR, n_ult)
        m_fus = t.rho_fus * ac["Sw_fus"] * t.k_fus
        m_tail = t.rho_tail * (ac["S_ht"] + ac["S_vt"]) * t.k_tail
        m_gear = t.f_gear * m0 * t.k_gear
        m_else = t.f_else * m0
        m_HV = t.m_HV
        if t.airframe == "v18":           # one regression replaces fuselage/tails/gear/all-else
            m_fus = (0.92 * m0 ** -0.05 - 0.23) * m0 * t.k_v18_struct * t.k_v18_airframe
            m_tail = m_gear = m_else = 0.0
            m_HV = t.m_sys_v18            # v18 systems allowance (incl. HV, BMS, TMS, avionics)
        k_m = 1 / t.sp_mot + 1 / t.sp_inv
        m_gen = P_ts / t.sp_ts + P_ts * t.eta_gen / t.sp_gen
        if c.kind == "BW":
            m_mot = (P_hl + P_cr) * k_m
            m_prop = c.n_cr_props * t.k_prop * c.D_cr ** 2 + c.n_hl * (t.k_prop * ac["D_hl"] ** 2 + c.m_hl_nac)
        else:
            m_mot = (P_lift * (1 + 0.15 * (c.lanes - 1)) + 1.10 * P_cr) * k_m      # lanes, combiner
            m_prop = (c.n_rot * (c.m_rotor4 * (c.D_rot / 4) ** 2.2 + c.m_boom)
                      + t.k_prop * c.D_push ** 2)
        m_cool = t.f_cool * (m_mot + m_gen)
        parts = dict(payload=m_pay, wing=m_wing, fuselage=m_fus, tails=m_tail, gear=m_gear,
                     all_else=m_else, motors_inverters=m_mot + m_cool, genset=m_gen,
                     props_rotors=m_prop, HV_system=m_HV, battery=m_bat, fuel=fuel)
        m_new = sum(parts.values())
        if not math.isfinite(m_new) or m_new > 20000:
            return None
        if abs(m_new - m0) < 0.5:
            m0 = m_new
            break
        m0 += 0.5 * (m_new - m0)
    else:
        return None
    r = dict(kind=c.kind, ws=ws, AR=AR, mtow=m0, ac=ac, parts=parts, ld_cr=ld_cr, CL_cr=CL_cr,
             P_cr=P_cr, P_cr_req=P_cr_req, P_lift=P_lift, P_ts=P_ts, m_bE=m_bE, m_bP=m_bP,
             E_bat=E_bat, E_use=E_use, R_el=R_el, R_fuel=R_fuel, s_cl=s_cl, s_de=s_de,
             fuel_mis=fuel_mis, fuel_res=fuel_res, E_TO=E_TO, E_LD=E_LD, E_fix=E_fix,
             s_TO=s_TO, s_LD=s_LD, n_man=n_man, n_gust=n_gust, n_ult=n_ult,
             t_block=(t_cl + (R_fuel + R_el) * NMI / V + s_de * NMI / V) / 3600 + 0.15)
    if c.kind == "BW":
        r.update(bw=bwi, to=toi, ld=ldi)
    else:
        r.update(lift=liftinfo, D_rot=c.D_rot)
    r["R_allel"] = all_electric_range(r, c, t)
    r["checks"] = checks(r, c, t)
    r["ok"] = all(v >= 0 for v in r["checks"].values())
    return r


def all_electric_range(r, c, t):
    """Point-to-point on the battery only (IFR fuel reserve on board):
    take-off, climb, cruise, glide, landing, taxi."""
    ac, V, h = r["ac"], t.V_cr, t.h_cr
    W = (r["mtow"] - r["fuel_mis"]) * G
    ld_cr, _ = LD(ac, W, V, h); ld_cl, _ = LD(ac, W, t.v_climb, h / 2)
    t_cl = h / REQ.roc_min
    E_cl = (W * (t.v_climb / ld_cl + REQ.roc_min) / (t.eta_prop * eta_bus(t)) + t.P_aux) * t_cl / t.eta_batt
    E_left = r["E_use"] - r["E_fix"] - E_cl
    if E_left <= 0:
        return 0.0
    e_m = W / (ld_cr * eta_batt_thrust(t)) + t.P_aux / (V * t.eta_batt)
    return r["s_cl"] + E_left / e_m / NMI + r["s_de"]


def checks(r, c, t):
    """Margins >= 0 are OK. Only RFP items are hard; heliport optional."""
    ck = dict(MTOW_19000lb=1 - r["mtow"] / REQ.mtow_max,
              takeoff_300ft=1 - r["s_TO"] / REQ.s_field,
              landing_300ft=1 - r["s_LD"] / REQ.s_land,
              range_400nmi=0.0 if (r["R_fuel"] + r["R_el"] + r["s_cl"] + r["s_de"]) >= REQ.R_total - 0.5 else -1.0)
    if c.heliport and c.kind == "VTOL":
        ck.update(heli_MTOW=1 - r["mtow"] / c.heli_mtow, heli_D=1 - r["ac"]["ctrl_D"] / c.heli_D)
    return ck


# =============================================================================
#  5  SEARCH
# =============================================================================
GRID = dict(BW=dict(ws=np.arange(300, 2601, 100), AR=(5, 6, 8, 10, 12, 14, 16), D=(None,),
                   CL=(5.0, 6.0, 7.0, 8.0, 9.0)),
            VTOL=dict(ws=np.arange(1500, 4401, 250), AR=(8, 10, 12, 14, 16, 18), D=(2.5, 3.0, 3.5, 4.0, 4.5, 5.0)))


def search(c, t):
    rows = []
    variants = ([replace(c, CLmax_bl=CL) for CL in GRID["BW"]["CL"] if CL <= c.CLmax_bl_max]
                if c.kind == "BW" else [replace(c, D_rot=D) for D in GRID["VTOL"]["D"]])
    for cc in variants:
        for ws in GRID[c.kind]["ws"]:
            for AR in GRID[c.kind]["AR"]:
                r = size(cc, t, float(ws), float(AR))
                if r:
                    r["c"] = cc
                    rows.append(r)
    ok = [r for r in rows if r["ok"]]
    if ok:
        return min(ok, key=lambda r: r["mtow"]), rows
    # nothing closes: lightest design that meets MTOW + take-off, else least violation
    part = [r for r in rows if r["checks"]["MTOW_19000lb"] >= 0 and r["checks"]["takeoff_300ft"] >= 0]
    if part:
        return min(part, key=lambda r: r["mtow"]), rows
    viol = lambda r: sum(-v for v in r["checks"].values() if v < 0)
    return (min(rows, key=lambda r: (round(viol(r), 2), r["mtow"])) if rows else None), rows


# =============================================================================
#  OUTPUT: report, constraint diagram, comparison plots
# =============================================================================
def report(r, t):
    c, ac, p = r["c"], r["ac"], r["parts"]
    name = ("BLOWN-WING DEP STOL" if r["kind"] == "BW" else "LIFT + CRUISE eVTOL") + f"  [airframe: {t.airframe}]"
    print("=" * 78)
    print(f" {name}:  W/S {r['ws']:.0f} N/m^2 ({r['ws'] / G * 0.2048:.1f} lb/ft^2), AR {r['AR']:.0f}"
          + (f", rotor D {c.D_rot:.1f} m" if r["kind"] == "VTOL" else f", {c.n_hl} HL props D {ac['D_hl']:.2f} m, CLmax_blown {c.CLmax_bl:.0f}"))
    print("=" * 78)
    print(f" MTOW {r['mtow']:.0f} kg = {r['mtow'] / LB:.0f} lb   (RFP <= 19,000 lb)   "
          f"{'ALL RFP CONSTRAINTS MET' if r['ok'] else 'CONSTRAINT VIOLATED'}")
    print(f" S {ac['S']:.1f} m^2, b {ac['b']:.1f} m, CD0 {ac['CD0']:.4f}, L/D cruise {r['ld_cr']:.1f}"
          f" (CL {r['CL_cr']:.2f}), L/D max {ac['LDmax']:.1f}")
    for k, v in p.items():
        print(f"   {k:<17s}{v:7.0f} kg {100 * v / r['mtow']:5.1f} %")
    print(f" power: cruise props {r['P_cr'] / 1e3:.0f} kW (largest requirement: {max(r['P_cr_req'], key=r['P_cr_req'].get)}),"
          f" {'high-lift' if r['kind'] == 'BW' else 'lift rotors'} {r['P_lift'] / 1e3:.0f} kW,"
          f" turboshaft {r['P_ts'] / 1e3:.0f} kW SL")
    print(f" P_total/W {(r['P_cr'] + r['P_lift']) / (r['mtow'] * G):.1f} W/N;"
          f" battery {'energy' if r['m_bE'] >= r['m_bP'] else 'POWER'}-sized, usable {r['E_use'] / 3.6e6:.0f} kWh")
    print(f" 400 nmi mission: climb {r['s_cl']:.0f} + fuel cruise {r['R_fuel']:.0f} + electric cruise"
          f" {r['R_el']:.0f} + glide {r['s_de']:.0f} nmi; fuel {r['fuel_mis']:.0f} kg + IFR reserve {r['fuel_res']:.0f} kg")
    print(f" all-electric range {r['R_allel']:.0f} nmi (objective {REQ.R_el_obj:.0f});"
          f" block time 400 nmi {r['t_block'] * 60:.0f} min")
    if r["kind"] == "BW":
        print(f" take-off {r['s_TO'] / FT:.0f} ft (ground {r['to']['s_G'] / FT:.0f} ft, V_LO {r['to']['V_LO'] / KT:.0f} kt,"
              f" climb {r['to']['gamma']:.0f} deg); landing {r['s_LD'] / FT:.0f} ft"
              f" (V_app {r['ld']['Va'] / KT:.0f} kt, path {r['ld']['gamma']:.1f} deg)")
        print(f" blowing power: take-off {r['bw']['P_blow_TO'] / 1e3:.0f} kW, approach {r['bw']['P_blow_LD'] / 1e3:.0f} kW")
    else:
        L = r["lift"]
        print(f" transition to wing-borne at {L['V_wing'] / KT:.0f} kt, {L['t_eq']:.0f} s full-hover-equivalent per take-off/landing")
        print(f" vertical take-off/landing: hover {L['hover'] / 1e3:.0f} kW, climb {L['climb'] / 1e3:.0f} kW,"
              f" one lane out {L['OEI_lane'] / 1e3:.0f} kW; disk loading {r['mtow'] * G / r['ac']['A_rot']:.0f} N/m^2")
        hp5 = vtol_lift_power(r["ac"], c, t, rho=rho_isa(5000 * FT, t.dT_field))[1]["hover"]
        print(f" heliport (FAA EB 105A, optional): D {ac['ctrl_D']:.1f} m (ref. {c.heli_D} m),"
              f" MTOW {'<=' if r['mtow'] <= c.heli_mtow else '>'} {c.heli_mtow:.0f} kg,"
              f" HOGE margin 5000 ft hot {r['P_lift'] / hp5:.2f}; TLOF >= {ac['RD']:.1f} m, FATO >= {2 * ac['RD']:.1f} m")
    print(f" load factors: manoeuvre {r['n_man']:.2f}, gust {r['n_gust']:.2f}, n_ult {r['n_ult']:.2f}")
    print(" margins (>= 0 ok): " + ", ".join(f"{k} {v:+.2f}" for k, v in r["checks"].items()))


def constraint_diagram(r, t, ax):
    """P/W vs W/S at the design MTOW (Metabook Ch. 4 style)."""
    c = r["c"]; m0 = r["mtow"]
    wss = np.linspace(GRID[c.kind]["ws"][0] * 0.6, GRID[c.kind]["ws"][-1] * 1.2, 45)
    lines = {k: [] for k in ("cruise", "ROC_1500", "FAR23_2120a", "FAR23_2120b", "FAR23_2120c")}
    lift = []
    for ws in wss:
        ac = geometry(c, t, m0, ws, r["AR"]); W = ac["W"]
        ld, _ = LD(ac, 0.97 * W, t.V_cr, t.h_cr)
        _, req = cruise_prop_power(ac, t, W, ld)
        for k in lines:
            lines[k].append(req[k] / W)
        if c.kind == "BW":
            P, _ = bw_power(ac, c, t, r["P_cr"])
            ok = bw_takeoff(ac, c, t, P, r["P_cr"])[0] <= REQ.s_field + 0.01
            lift.append((P + r["P_cr"]) / W if ok else np.nan)
        else:
            lift.append(vtol_lift_power(ac, c, t)[0] / W)
    for k, v in lines.items():
        ax.plot(wss, v, label=f"cruise props: {k}")
    ax.plot(wss, lift, "k-", lw=2, label="take-off 300 ft (HL + cruise props)" if c.kind == "BW"
            else "lift rotors: hover/climb/OEI")
    if c.kind == "BW":                                      # landing: max W/S
        ok = [ws for ws in wss if bw_landing(geometry(c, t, m0, ws, r["AR"]), c, t, r["P_cr"])[0] <= REQ.s_land]
        if ok:
            ax.axvline(max(ok), color="r", lw=2, label="landing 300 ft (max W/S)")
        else:
            ax.text(0.03, 0.95, "landing 300 ft: not reachable at any W/S\n(approach angle limited by D - T_blow)",
                    transform=ax.transAxes, color="r", fontsize=8, va="top")
        if np.all(np.isnan(lift)):
            ax.text(0.03, 0.85, "take-off 300 ft: not reachable at MTOW", transform=ax.transAxes,
                    color="k", fontsize=8, va="top")
    ax.plot(r["ws"], (r["P_cr"] + r["P_lift"]) / (m0 * G) if c.kind == "BW" else r["P_lift"] / (m0 * G),
            "r*", ms=16, label="design point")
    ax.set_xlabel("W/S [N/m$^2$]"); ax.set_ylabel("P/W [W/N]")
    ax.set_ylim(0, 60); ax.grid(alpha=0.3); ax.legend(fontsize=7)
    ax.set_title(f"{'Blown wing' if c.kind == 'BW' else 'Lift + cruise'}: constraint diagram at MTOW {m0:.0f} kg")


def plots(res, rows, t):
    fig, axs = plt.subplots(1, 2, figsize=(15, 6))
    for ax, k in zip(axs, ("BW", "VTOL")):
        constraint_diagram(res[k], t, ax)
    fig.tight_layout(); fig.savefig(OUT / "constraint_diagrams.png", dpi=130); plt.close(fig)
    fig, axs = plt.subplots(1, 2, figsize=(15, 5.5))
    keys = list(res["BW"]["parts"])
    bottom = np.zeros(2)
    for k in keys:
        v = np.array([res[x]["parts"][k] for x in ("BW", "VTOL")])
        axs[0].bar(["blown wing", "lift + cruise"], v, bottom=bottom, label=k); bottom += v
    axs[0].axhline(REQ.mtow_max, color="r", ls="--", label="RFP 19,000 lb")
    axs[0].set_ylabel("mass [kg]"); axs[0].legend(fontsize=7, ncol=2); axs[0].set_title("Mass breakdown")
    for k, st in (("BW", "o-"), ("VTOL", "s--")):
        rr = [r for r in rows[k] if r["ok"]]
        for AR in sorted({r["AR"] for r in rr}):
            best = {}
            for r in rr:
                if r["AR"] == AR and (r["ws"] not in best or r["mtow"] < best[r["ws"]]):
                    best[r["ws"]] = r["mtow"]
            xs = sorted(best)
            axs[1].plot(xs, [best[x] for x in xs], st, ms=3, label=f"{k} AR {AR:.0f}")
    axs[1].set_xlabel("W/S [N/m$^2$]"); axs[1].set_ylabel("MTOW [kg]"); axs[1].grid(alpha=0.3)
    axs[1].legend(fontsize=7, ncol=2); axs[1].set_title("Feasible designs (all RFP constraints met)")
    fig.tight_layout(); fig.savefig(OUT / "mass_and_trade.png", dpi=130); plt.close(fig)


def bw_sensitivity(t, CLs=(5.0, 7.0, 9.0)):
    """Blown wing: what does it take? Best design per CLmax_bl, with and
    without the 200 nmi electric objective (coarse grid)."""
    print(" BLOWN-WING SENSITIVITY (coarse grid; hard = RFP take-off, landing, MTOW)")
    for obj in (True, False):
        tt = replace(t, electric_objective=obj)
        for CL in CLs:
            c = Concept(kind="BW", CLmax_bl=CL)
            rr = [size(c, tt, float(ws), float(AR)) for ws in range(400, 2001, 200) for AR in (6, 8, 10)]
            rr = [r for r in rr if r]
            ok = [r for r in rr if r["checks"]["MTOW_19000lb"] >= 0 and r["checks"]["takeoff_300ft"] >= 0]
            b = min(ok, key=lambda r: r["mtow"]) if ok else None
            s_min = min(r["s_TO"] for r in rr) / FT if rr else float("nan")
            txt = (f"MTOW {b['mtow']:5.0f} kg @ W/S {b['ws']:.0f}, AR {b['AR']:.0f}, landing {b['s_LD'] / FT:.0f} ft"
                   if b else f"no design with 300 ft take-off and <= 19,000 lb (shortest take-off {s_min:.0f} ft)")
            print(f"   CLmax_bl {CL:4.1f}, 200 nmi objective {'on ' if obj else 'off'}: {txt}")


RUN_SENSITIVITY = False                    # blown-wing CLmax / electric-objective study (+30 s)

if __name__ == "__main__":
    t0 = time.time()
    concepts = dict(BW=Concept(kind="BW"), VTOL=Concept(kind="VTOL"))
    RESULTS = {}                                           # (concept, airframe method) -> design
    for method in ("raymer_ga", "v18"):
        tech = Tech(airframe=method)
        res, rows = {}, {}
        for k, c in concepts.items():
            res[k], rows[k] = search(c, tech)
            RESULTS[(k, method)] = res[k]
            report(res[k], tech)
        if method == "raymer_ga":                          # plots for the primary method
            plots(res, rows, tech)
    # ---- four-mass summary: each concept, each airframe method (fully re-sized)
    print("=" * 78)
    print(" SUMMARY  (each design fully re-sized with its airframe method)")
    print(f" {'concept':<16s}{'airframe':<11s}{'MTOW kg':>8s}{'MTOW lb':>8s}{'airframe kg':>12s}"
          f"{'battery':>8s}{'W/S':>6s}{'AR':>4s}  RFP")
    for (k, method), r in RESULTS.items():
        p = r["parts"]
        af = p["fuselage"] + p["tails"] + p["gear"] + p["all_else"] + p["HV_system"]
        print(f" {('blown wing' if k == 'BW' else 'lift+cruise'):<16s}{method:<11s}{r['mtow']:8.0f}"
              f"{r['mtow'] / LB:8.0f}{af:12.0f}{p['battery']:8.0f}{r['ws']:6.0f}{r['AR']:4.0f}"
              f"  {'all met' if r['ok'] else 'violated: ' + ', '.join(n for n, v in r['checks'].items() if v < 0)}")
    print(" airframe kg = fuselage + tails + gear + all-else + systems (wing and propulsion identical methods)")
    if RUN_SENSITIVITY:
        bw_sensitivity(Tech())
    print(f" plots in {OUT}   run time {time.time() - t0:.1f} s")
