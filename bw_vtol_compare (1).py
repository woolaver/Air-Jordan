# -*- coding: utf-8 -*-
"""
===============================================================================
 BW_VTOL_COMPARE  -  fair, simple conceptual comparison
     Blown-wing DEP STOL  (BW)   vs.   lift + cruise VTOL  (VT)
 one mission, one technology level, one set of methods, one optimiser
===============================================================================

 SCENARIOS (all four are sized separately)
   all-electric range objective  150 / 200 nmi
   design cruise speed           225 / 250 kt        (12,000 ft, unpressurised)
   total range                   400 nmi + IFR fuel reserve
   field (HARD)                  take-off and landing <= 300 ft over 50 ft,
                                 worst case: hot & high (5000 ft, ISA+18 degF)

 CONFIGURATIONS (every one is re-sized for every scenario)
   BW   6 / 8 / 10 blown high-lift props,
        with 2 dedicated wing-tip cruise props  (HL props fold in cruise)
        or without dedicated cruise props       (HL props are variable pitch
                                                 and also give cruise thrust)
   VT   4 / 6 lift rotors, 2 / 3 motor lanes per lift rotor, 1 pusher
        runway mode (lift power just enough for 300 ft / 50 ft) or
        optional heliport mode (HOGE + 500 fpm vertical climb + lane-out hover)
   both series or parallel turbo-generator hybrid
        (parallel = turboshaft geared to the cruise propulsor; not possible
         for a BW without dedicated cruise props -> not generated)
   both battery with 2 or 4 independent segments, 420 Wh/kg pack level

 DESIGN VARIABLES (optimiser: coarse grid + compass search, minimum MTOW)
   W/S <= 4400 N/m^2, AR <= 18, BW blown CLmax 4.5 ... 9, VT disk loading

 FAIRNESS RULES (identical for BW and VT)
   same payload, mission, reserves, technology, efficiencies, specific powers,
   airframe mass method (Raymer), drag build-up, climb requirements,
   field-performance method (Raymer 17.8/17.9), approach-angle limit for any
   wing-borne approach, single-failure philosophy:
     - one motor (BW) / one motor lane (VT) lost -> remaining motors at the
       30-s emergency rating must still give the take-off power
     - turbine lost at take-off -> battery alone gives take-off power
     - one battery segment lost -> remaining segments + turbine give it
   A VT that can hover at the hot & high field may land and take off
   vertically (that is what a VTOL is); a wing-borne approach of either
   concept is limited to gamma_app.

 METHODS / SOURCES
   [R]  D. P. Raymer, Aircraft Design: A Conceptual Approach, 6th ed., AIAA
        2018: Tab. 6.3 fuselage length, Tab. 6.4 tail volume coefficients,
        Tab. 12.3 equivalent skin friction, Eq. 15.25 wing mass,
        Tab. 17.1 rolling/braking friction, Sec. 17.8 take-off, 17.9 landing,
        Breguet range (Ch. 17).
   [L]  J. G. Leishman, Principles of Helicopter Aerodynamics, 2nd ed.,
        Cambridge UP 2006, Ch. 2: momentum theory (hover, axial climb,
        Glauert forward-flight inflow), figure of merit.
   [M]  B. W. McCormick, Aerodynamics, Aeronautics and Flight Mechanics,
        2nd ed., Wiley 1995, Ch. 6: actuator-disk propeller, ideal efficiency.
   [P]  M. D. Patterson, Conceptual Design of High-Lift Propeller Systems for
        Small Electric Aircraft, PhD thesis, Georgia Tech 2016 (slipstream
        dynamic-pressure model for blown lift).
   [CFR] 14 CFR 23 (pre-Amdt 64: 23.65 / 23.67 / 23.77 climb gradients, 23.341
        gust formula), 14 CFR 135.223 (IFR fuel reserve), 14 CFR 25.125 (no
        reverse-thrust credit for landing distance - adopted as worst case).
   Heliport envelope (12,500 lb, 15.2 m controlling dimension) taken over from
   the v18/v20 codes (FAA EB 105A) - verify against the current EB.

 Run:   python bw_vtol_compare.py            (~20-50 s, parallel processes)
        python bw_vtol_compare.py --fast     (smaller grid, ~10 s)
        python bw_vtol_compare.py --plots    (+ PNG plots)
        python bw_vtol_compare.py --jobs 1   (single process)
===============================================================================
"""
from dataclasses import dataclass, replace
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import argparse, csv, math, os, time
import numpy as np

_trapz = np.trapezoid if hasattr(np, "trapezoid") else np.trapz

G, FT, KT, NMI, LB, HP, WH = 9.80665, 0.3048, 1852.0 / 3600.0, 1852.0, 0.45359237, 745.7, 3600.0
LHV = 43.0e6                                      # J/kg Jet-A
OUT = Path(__file__).with_name("bw_vtol_output")


# =============================================================================
#  REQUIREMENTS (hard) and SCENARIOS
# =============================================================================
@dataclass(frozen=True)
class RFP:
    n_occ: int = 8                                # 1 pilot + 7 passengers
    m_occ: float = (190 + 30) * LB                # kg per occupant incl. baggage
    R_total: float = 400.0                        # nmi
    s_TO: float = 300.0 * FT                      # take-off over 50 ft
    s_LD: float = 300.0 * FT                      # landing over 50 ft
    h_obs: float = 50.0 * FT
    roc_min: float = 1500.0 * FT / 60.0           # m/s, sea level hot day
    mtow_max: float = 19000.0 * LB
    ws_max: float = 4400.0                        # N/m^2
    AR_max: float = 18.0
    CLbl_min: float = 4.5
    CLbl_max: float = 9.0


REQ = RFP()


@dataclass(frozen=True)
class Scenario:
    R_el: float                                   # nmi all-electric range objective
    V_kt: float                                   # kt design cruise speed

    @property
    def name(self):
        return f"E{self.R_el:.0f}nm/{self.V_kt:.0f}kt"


SCENARIOS = tuple(Scenario(r, v) for r in (150.0, 200.0) for v in (225.0, 250.0))


# =============================================================================
#  COMMON TECHNOLOGY / ASSUMPTIONS (identical for both concepts)
# =============================================================================
@dataclass(frozen=True)
class Tech:
    h_cr: float = 12000.0 * FT
    v_climb: float = 150.0 * KT
    # battery (pack level)
    e_pack: float = 420.0 * WH                    # J/kg
    f_usable: float = 0.90
    p_pack: float = 2.2e3                         # W/kg peak
    m_seg: float = 6.0                            # kg per independent segment (contactors, fuses, BMS, case)
    # efficiencies
    eta_batt: float = 0.97
    eta_cable: float = 0.997
    eta_inv: float = 0.995
    eta_mot: float = 0.97
    eta_gen: float = 0.98
    eta_gbx: float = 0.98                         # parallel hybrid combining gearbox
    eta_visc: float = 0.88                        # propeller profile efficiency (x ideal disk) [M]
    FM: float = 0.82                              # static figure of merit, props and rotors [L]
    # turboshaft
    sfc: float = 0.40 * LB / (HP * 3600.0)        # kg/J (0.40 lb/hp/h)
    n_lapse: float = 0.75                         # P ~ sigma^n
    f_rating: float = 0.80                        # cruise at <= 80 % rating
    # specific powers (optimistic EIS 2035)
    sp_mot: float = 8.0e3
    sp_inv: float = 20.0e3
    sp_gen: float = 12.0e3
    sp_ts: float = 5.0e3
    sp_gbx: float = 10.0e3
    f_cool: float = 0.10
    m_HV: float = 70.0
    P_aux: float = 3.0e3
    k_em: float = 1.20                            # emergency rating, climb / cruise
    k_em_short: float = 1.30                      # 30-s rating, take-off / landing
    k_lane: float = 0.15                          # motor-mass penalty per extra lane
    # aerodynamics
    Cfe: float = 0.0040                           # [R] Tab. 12.3
    e_clean: float = 0.825
    CLmax_clean: float = 1.60
    dCL_TO: float = 0.65
    dCL_LDG: float = 1.00
    dCD0_TO: float = 0.015; e_TO: float = 0.775
    dCD0_LDG: float = 0.065; e_LDG: float = 0.725
    dCD0_gear: float = 0.020
    dCL_climb: float = 0.20
    # structure [R] Ch. 15, composite factors
    t_c: float = 0.14; taper: float = 0.6; f_csw: float = 0.30
    k_wing: float = 0.85; k_fus: float = 0.92; k_tail: float = 0.85; k_gear: float = 0.95
    rho_fus: float = 7.0; rho_tail: float = 10.0
    f_gear: float = 0.057; f_else: float = 0.10
    k_prop: float = 6.66                          # kg/m^2, propeller ~ D^2
    # mission / reserves
    R_alt: float = 50.0                           # nmi alternate
    t_res: float = 45.0 * 60.0                    # s  (14 CFR 135.223)
    f_trapped: float = 0.01
    E_taxi: float = 3.0e3 * WH
    h_desc_end: float = 1500.0 * FT
    # field performance (worst case: hot & high, dry paved) [R] Tab. 17.1
    h_field: float = 5000.0 * FT                  # field elevation
    dT_field: float = 10.0                        # K, ISA+18 degF hot day (RFP hot day)
    mu_roll: float = 0.04
    mu_brake: float = 0.40
    f_rev: float = 0.0                            # no reverse-thrust credit (worst case)
    t_rot: float = 1.0
    t_free: float = 1.0
    n_flare: float = 1.2
    gamma_app: float = 12.0                       # deg, max wing-borne approach angle (both)
    gamma_TO: float = 20.0                        # deg, max climb angle after lift-off (both)
    # blown wing [P]
    f_blown: float = 0.80
    k_blow: float = 1.0
    CL_ground: float = 1.0
    dj_LD: float = 60.0
    dj_TO: float = 15.0
    D_cr: float = 2.0
    m_hl_nac: float = 3.0
    m_vp: float = 4.0                             # variable-pitch hub if HL props also cruise
    # lift + cruise
    k_download: float = 1.05
    vz_TO: float = 2.5                            # m/s (~500 fpm) vertical climb
    t_hover: float = 10.0
    a_tr: float = 1.5
    m_rotor4: float = 25.0                        # kg per rotor at D = 4 m, ~D^2.2
    k_boom: float = 10.0                          # kg/m boom
    f_rot_stop: float = 0.02                      # m^2 drag area per stopped 4-m rotor
    D_push: float = 2.6
    push_lanes: int = 2
    T_edge_max: float = 1.3                       # edgewise thrust cap / hover thrust
    CL_ground_vt: float = 0.6
    # optional heliport envelope (v18/v20: FAA EB 105A)
    heli_mtow: float = 12500.0 * LB
    heli_D: float = 15.2


TECH = Tech()


# =============================================================================
#  CONFIGURATIONS
# =============================================================================
@dataclass(frozen=True)
class Config:
    kind: str                                     # "BW" or "VT"
    n_hl: int = 0
    n_cr: int = 0
    n_rot: int = 0
    lanes: int = 0
    hybrid: str = "series"                        # "series" or "parallel"
    n_seg: int = 2
    heli: bool = False

    @property
    def name(self):
        h = "ser" if self.hybrid == "series" else "par"
        if self.kind == "BW":
            cr = f"+{self.n_cr}CR" if self.n_cr else "-noCR"
            return f"BW{self.n_hl}{cr}-{h}-B{self.n_seg}"
        return f"VT{self.n_rot}R{self.lanes}L-{h}-B{self.n_seg}" + ("-HELI" if self.heli else "")

    @property
    def family(self):
        if self.kind == "BW":
            return "BW +CR" if self.n_cr else "BW noCR"
        return "VT heliport" if self.heli else "VT runway"


def all_configs():
    cfgs = []
    for n in (6, 8, 10):
        for ncr in (2, 0):
            for hyb in (("series", "parallel") if ncr else ("series",)):
                for seg in (2, 4):
                    cfgs.append(Config("BW", n_hl=n, n_cr=ncr, hybrid=hyb, n_seg=seg))
    for nr in (4, 6):
        for L in (2, 3):
            for hyb in ("series", "parallel"):
                for seg in (2, 4):
                    for heli in (False, True):
                        cfgs.append(Config("VT", n_rot=nr, lanes=L, hybrid=hyb, n_seg=seg, heli=heli))
    return cfgs


# =============================================================================
#  ATMOSPHERE, EFFICIENCY CHAINS, PROPULSORS
# =============================================================================
def rho_isa(h, dT=0.0):
    T = 288.15 - 0.0065 * h
    return 101325.0 * (T / 288.15) ** 5.25588 / (287.053 * (T + dT))


RHO_SL = rho_isa(0.0)


def rho_field(t):                                 # hot & high field
    return rho_isa(t.h_field, t.dT_field)


def rho_slh(t):                                   # sea level, hot day (ROC requirement)
    return rho_isa(0.0, t.dT_field)


def lapse(t, rho):
    return (rho / RHO_SL) ** t.n_lapse


def eta_bus(t):                                   # DC bus -> shaft
    return t.eta_cable * t.eta_inv * t.eta_mot


def eta_disk(t, T, V, A, rho):
    """Propeller efficiency = profile efficiency x ideal actuator-disk efficiency [M]."""
    return t.eta_visc * 2.0 / (1.0 + math.sqrt(1.0 + T / (0.5 * rho * V * V * A)))


def prop_thrust(P, V, A, rho, FM):
    """Axial actuator disk: T (V/2 + sqrt(V^2/4 + T/(2 rho A))) = FM P  [L, M].
    Vectorised in V; Newton from the static value (convex -> monotone)."""
    V = np.asarray(V, dtype=float)
    if P <= 0.0 or A <= 0.0:
        return np.zeros_like(V)
    T = np.full_like(V, (FM * P) ** (2 / 3) * (2 * rho * A) ** (1 / 3))
    for _ in range(6):
        s = np.sqrt(0.25 * V * V + T / (2 * rho * A))
        T = T - (T * (0.5 * V + s) - FM * P) / (0.5 * V + s + T / (4 * rho * A * s))
    return T


def rotor_thrust(P, V, A, rho, t):
    """Lift rotor, disk horizontal, flight speed V in the disk plane:
    Glauert T = 2 rho A v_i sqrt(V^2 + v_i^2), FM P = T v_i  [L Ch. 2].
    Capped at T_edge_max x hover thrust (blade loading)."""
    V = np.asarray(V, dtype=float)
    if P <= 0.0:
        return np.zeros_like(V)
    Pp = t.FM * P
    xh = (Pp / (2 * rho * A)) ** (1 / 3)
    x = np.full_like(V, xh)
    for _ in range(7):
        s = np.sqrt(V * V + x * x)
        x = x - (2 * rho * A * x * x * s - Pp) / (2 * rho * A * (2 * x * s + x ** 3 / s))
    return np.minimum(Pp / x, t.T_edge_max * Pp / xh)


def hover_power(T, A, rho, t):
    return T * math.sqrt(T / (2 * rho * A)) / t.FM


def oei_factor(cfg, t):
    """Installed/required lift power so that one failure still leaves the
    required power at the 30-s rating.  BW: one HL motor lost, its mirror
    partner is throttled (roll trim).  VT: one lane of one rotor lost, the
    diagonal/opposite partner is trimmed to the same thrust, P ~ T^1.5."""
    if cfg.kind == "BW":
        n = cfg.n_hl
        return max(1.0, n / ((n - 2) * t.k_em_short))
    f_lane = ((cfg.lanes - 1) / cfg.lanes) ** (2 / 3)
    cap = (cfg.n_rot - 2 + 2 * f_lane) / cfg.n_rot
    return max(1.0, cap ** -1.5 / t.k_em_short)


# =============================================================================
#  GEOMETRY + DRAG (same build-up for both)
# =============================================================================
def geometry(cfg, t, m0, ws, AR, DL=None):
    W = m0 * G; S = W / ws; b = math.sqrt(AR * S); c = S / b
    L = 0.169 * m0 ** 0.51                        # [R] Tab. 6.3 twin turboprop, metric
    d = math.sqrt(1.6 * 1.8); fr = L / d
    Sw_fus = math.pi * d * L * (1 - 2 / fr) ** (2 / 3) * (1 + 1 / fr ** 2)
    l_t = 0.5 * L
    S_ht, S_vt = 0.90 * c * S / l_t, 0.08 * b * S / l_t      # [R] Tab. 6.4
    Sw = Sw_fus + 2.05 * (S - 1.6 * c) + 2.03 * (S_ht + S_vt)
    g = dict(W=W, m0=m0, S=S, b=b, c=c, AR=AR, L=L, Sw_fus=Sw_fus, S_ht=S_ht, S_vt=S_vt)
    f_extra = 0.0
    if cfg.kind == "BW":
        D_hl = t.f_blown * max(b - 1.6, 1.0) / cfg.n_hl
        A_hl = cfg.n_hl * math.pi * D_hl ** 2 / 4
        A_cr = cfg.n_cr * math.pi * t.D_cr ** 2 / 4
        Sw += cfg.n_hl * math.pi * 0.25 * 0.8 + cfg.n_cr * math.pi * 0.45 * 1.6   # nacelles
        g.update(D_hl=D_hl, A_hl=A_hl, A_cr=A_cr, A_climb=A_hl + A_cr,
                 A_cruise=A_cr if cfg.n_cr else A_hl, ctrl_D=max(b, L), fit=1.0)
    else:
        A_rot = W / DL
        D = math.sqrt(4 * A_rot / (math.pi * cfg.n_rot))
        y_boom = 0.8 + D / 2 + 0.3
        l_boom = (cfg.n_rot / 2 - 1) * 1.1 * D + c + 0.6
        Sw += 2 * math.pi * 0.3 * l_boom
        f_extra = cfg.n_rot * t.f_rot_stop * (D / 4) ** 2
        rd = 2 * (math.hypot(y_boom, l_boom / 2) + D / 2)
        A_p = math.pi * t.D_push ** 2 / 4
        g.update(D_rot=D, A_rot=A_rot, y_boom=y_boom, l_boom=l_boom, RD=rd, A_cr=A_p,
                 A_climb=A_p, A_cruise=A_p, ctrl_D=max(b, L, rd),
                 fit=1.0 - (y_boom + D / 2) / (b / 2))
    g["CD0"] = t.Cfe * Sw / S + f_extra / S
    g["K"] = 1 / (math.pi * AR * t.e_clean)
    g["LDmax"] = 0.5 / math.sqrt(g["CD0"] * g["K"])
    return g


def polar(g, t, cfg, gear):
    if cfg == "clean":
        return g["CD0"], g["K"]
    dCD, e = (t.dCD0_TO, t.e_TO) if cfg == "TO" else (t.dCD0_LDG, t.e_LDG)
    return g["CD0"] + dCD + (t.dCD0_gear if gear else 0.0), 1 / (math.pi * g["AR"] * e)


def CL_limit(t, cfg):
    return t.CLmax_clean + {"clean": 0.0, "TO": t.dCL_TO, "LDG": t.dCL_LDG}[cfg]


def LD(g, W, V, rho):
    CL = W / (0.5 * rho * V * V * g["S"])
    return CL / (g["CD0"] + g["K"] * CL * CL), CL


_VCL = np.linspace(25.0, 110.0, 24)


def climb_power(g, t, W, grad, roc, cfg, gear, rho, A):
    """Min shaft power for a gradient / ROC at CL <= CLmax - 0.2 (best speed)."""
    CD0, K = polar(g, t, cfg, gear)
    q = 0.5 * rho * _VCL * _VCL
    CL = W / (q * g["S"])
    T = q * g["S"] * (CD0 + K * CL * CL) + W * (grad + roc / _VCL)
    P = T * (0.5 * _VCL + np.sqrt(0.25 * _VCL ** 2 + T / (2 * rho * A))) / t.FM
    P = np.where(CL <= CL_limit(t, cfg) - t.dCL_climb, P, np.inf)
    return float(P.min())


def air_distance(V, gam, t):
    """Raymer 17.8/17.9: circular transition/flare arc (n = n_flare) + straight
    segment to/from the 50-ft obstacle."""
    R = V * V / (G * (t.n_flare - 1))
    h_tr = R * (1 - math.cos(gam))
    if h_tr >= REQ.h_obs:
        return math.sqrt(max(R * R - (R - REQ.h_obs) ** 2, 0.0))
    return R * math.sin(gam) + (REQ.h_obs - h_tr) / math.tan(gam)


def brake_distance(g, t, V_td, P_cr, A_cr, rho):
    a_b = t.mu_brake * G + t.f_rev * float(prop_thrust(P_cr, 0.0, A_cr, rho, t.FM)) / (g["W"] / G)
    return V_td * t.t_free + V_td ** 2 / (2 * a_b)


# =============================================================================
#  BLOWN WING  [P] + [R] 17.8 / 17.9
# =============================================================================
def blow_r2(t, CL_target, CL_flap):
    """(V_slipstream/V)^2 so that the blown span share reaches CL_target."""
    return 1 + max(CL_target / CL_flap - 1, 0.0) / (t.f_blown * t.k_blow)


def blow_TP(g, t, V, r2, rho):
    vi = V * (math.sqrt(r2) - 1) / 2
    T = 2 * rho * g["A_hl"] * vi * (V + vi)
    return T, T * (V + vi) / t.FM


def bw_takeoff(g, t, CLbl, P_hl, P_cr, rho):
    W, S = g["W"], g["S"]; m = W / G
    Vs = math.sqrt(2 * W / (rho * S * CLbl))
    V_LO, V_TR = 1.1 * Vs, 1.15 * Vs
    CD0, K = polar(g, t, "TO", True)
    cj = math.cos(math.radians(t.dj_TO))
    V = np.append(np.linspace(0.0, V_LO, 13), V_TR)        # ground roll + transition speed
    T = cj * prop_thrust(P_hl, V, g["A_hl"], rho, t.FM) + prop_thrust(P_cr, V, g["A_cr"], rho, t.FM)
    q = 0.5 * rho * V * V
    F = T - q * S * (CD0 + K * t.CL_ground ** 2) - t.mu_roll * np.maximum(W - q * S * t.CL_ground, 0)
    Vg, Fg = V[:-1], F[:-1]
    if Fg.min() <= 0:
        return math.inf, None
    s_G = float(_trapz(m * Vg / Fg, Vg)); t_G = float(_trapz(m / Fg, Vg))
    CL_TR = CLbl / 1.15 ** 2
    sg = (T[-1] - q[-1] * S * (CD0 + K * CL_TR ** 2)) / W
    if sg <= 0:
        return math.inf, None
    gam = min(math.asin(min(sg, 0.9)), math.radians(t.gamma_TO))
    s_A = air_distance(V_TR, gam, t)
    return s_G + V_LO * t.t_rot + s_A, dict(t=t_G + t.t_rot + s_A / V_TR, V_LO=V_LO, gamma=math.degrees(gam))


def bw_landing(g, t, CLbl, rho, gamma_app=None):
    gamma_app = t.gamma_app if gamma_app is None else gamma_app
    W, S = g["W"], g["S"]
    Vs = math.sqrt(2 * W / (rho * S * CLbl))
    Va, Vf, Vtd = 1.3 * Vs, 1.23 * Vs, 1.15 * Vs
    T_bl, P_bl = blow_TP(g, t, Va, blow_r2(t, CLbl, CL_limit(t, "LDG")), rho)
    CD0, K = polar(g, t, "LDG", True)
    CLa = CLbl / 1.69
    D = 0.5 * rho * Va * Va * S * (CD0 + K * CLa * CLa)
    sg = (D - T_bl * math.cos(math.radians(t.dj_LD))) / W
    if sg <= 0:
        return math.inf, dict(gamma=0.0, gamma_phys=0.0, P_bl=P_bl, Va=Va, t_app=60.0)
    gp = math.asin(min(sg, 0.9)); gam = min(gp, math.radians(gamma_app))
    s = air_distance(Vf, gam, t) + brake_distance(g, t, Vtd, 0.0, 0.0, rho)
    return s, dict(gamma=math.degrees(gam), gamma_phys=math.degrees(gp), P_bl=P_bl, Va=Va,
                   t_app=min(500 * FT / (Va * math.sin(gam)), 120.0))


P_CAP = 40.0                                      # W/N, upper bound for high-lift power


def bw_hl_power(g, t, CLbl, P_cr, rho):
    """Required HL power (all engines): blowing power for the blown CLmax at
    lift-off and approach, then the smallest power for 300 ft (Illinois)."""
    Vs = math.sqrt(2 * g["W"] / (rho * g["S"] * CLbl))
    lo = max(blow_TP(g, t, 1.1 * Vs, blow_r2(t, CLbl, CL_limit(t, "TO")), rho)[1],
             blow_TP(g, t, 1.3 * Vs, blow_r2(t, CLbl, CL_limit(t, "LDG")), rho)[1])
    f = lambda P: bw_takeoff(g, t, CLbl, P, P_cr, rho)[0] - REQ.s_TO
    flo = f(lo)
    if flo <= 0:
        return lo
    hi = 2 * lo
    fhi = f(hi)
    while fhi > 0:                                # 300 ft not reachable -> cap, TO check fails
        if hi >= P_CAP * g["W"]:
            return hi
        hi = min(2 * hi, P_CAP * g["W"])
        fhi = f(hi)
    if not math.isfinite(flo):
        flo = 10 * REQ.s_TO
    side = 0
    for _ in range(30):                           # Illinois regula falsi
        P = (lo * fhi - hi * flo) / (fhi - flo)
        fP = f(P)
        if not math.isfinite(fP):
            fP = 10 * REQ.s_TO
        if abs(fP) < 1.0:
            return P if fP <= 0 else P * 1.003
        if fP > 0:
            lo, flo = P, fP
            if side == -1:
                fhi *= 0.5
            side = -1
        else:
            hi, fhi = P, fP
            if side == 1:
                flo *= 0.5
            side = 1
    return hi


# =============================================================================
#  LIFT + CRUISE VTOL: runway (rotor-assisted) and vertical modes
# =============================================================================
def vt_takeoff(g, t, P_rot, P_push, rho):
    W, S = g["W"], g["S"]; m = W / G; A = g["A_rot"]
    kd = t.k_download
    if float(rotor_thrust(P_rot, 0.0, A, rho, t)) >= kd * W * 1.02:
        return 0.0, dict(mode="vertical", t=(REQ.h_obs + 5) / t.vz_TO + t.t_hover, V_LO=0.0, gamma=90.0)
    CL_LO = CL_limit(t, "TO") / 1.21
    Vmax = 1.1 * math.sqrt(2 * W / (rho * S * CL_limit(t, "TO")))
    V = np.linspace(0.0, Vmax, 25)
    Tr = rotor_thrust(P_rot, V, A, rho, t) / kd
    q = 0.5 * rho * V * V
    ok = q * S * CL_LO + Tr >= W
    if not ok.any():
        return math.inf, None
    i = int(np.argmax(ok))
    if i == 0:
        V_LO = 1.0
    else:
        e0 = q[i - 1] * S * CL_LO + Tr[i - 1] - W; e1 = q[i] * S * CL_LO + Tr[i] - W
        V_LO = V[i - 1] + (V[i] - V[i - 1]) * (-e0) / (e1 - e0)
    CD0, K = polar(g, t, "TO", True)
    Vg = np.linspace(0.0, V_LO, 13); qg = 0.5 * rho * Vg * Vg
    Lg = qg * S * t.CL_ground_vt
    Trg = np.minimum(rotor_thrust(P_rot, Vg, A, rho, t) / kd, np.maximum(W - Lg, 0))
    F = (prop_thrust(P_push, Vg, g["A_cr"], rho, t.FM) - qg * S * (CD0 + K * t.CL_ground_vt ** 2)
         - t.mu_roll * np.maximum(W - Lg - Trg, 0))
    if F.min() <= 0:
        return math.inf, None
    s_G = float(_trapz(m * Vg / F, Vg)); t_G = float(_trapz(m / F, Vg))
    V2 = max(V_LO, 1.0); q2 = 0.5 * rho * V2 * V2
    X = float(prop_thrust(P_push, V2, g["A_cr"], rho, t.FM)) - q2 * S * (CD0 + K * CL_LO ** 2)
    if X <= 0:
        return math.inf, None
    Tr2 = float(rotor_thrust(P_rot, V2, A, rho, t)) / kd
    sg = X / max(W - Tr2, 1e-3 * W)               # sin(gamma) = (T_p - D)/(W - T_rotor)
    gam = min(math.asin(min(sg, 1.0)), math.radians(t.gamma_TO))
    s_A = air_distance(V2, gam, t)
    return s_G + V_LO * t.t_rot + s_A, dict(mode="rolling", t=t_G + t.t_rot + s_A / V2, V_LO=V_LO,
                                          gamma=math.degrees(gam))


def vt_landing(g, t, P_rot, rho, gamma_app=None):
    gamma_app = t.gamma_app if gamma_app is None else gamma_app
    W, S = g["W"], g["S"]; A = g["A_rot"]; kd = t.k_download
    if float(rotor_thrust(P_rot, 0.0, A, rho, t)) >= kd * W:
        return 0.0, dict(mode="vertical", t=(REQ.h_obs + 5) / t.vz_TO + t.t_hover, gamma=90.0, P_app=P_rot)
    CLm = CL_limit(t, "LDG")
    V = np.linspace(0.0, math.sqrt(2 * W / (rho * S * CLm)), 25)
    Tr = rotor_thrust(P_rot, V, A, rho, t) / kd
    ok = 0.5 * rho * V * V * S * CLm + Tr >= W
    V_se = float(V[int(np.argmax(ok))]) if ok.any() else float(V[-1])
    V_se = max(V_se, 1.0)
    Va, Vf, Vtd = 1.3 * V_se, 1.23 * V_se, 1.15 * V_se
    qa = 0.5 * rho * Va * Va; CLa = CLm / 1.69
    Tr_need = max(W - qa * S * CLa, 0.0)
    CD0, K = polar(g, t, "LDG", True)
    D = qa * S * (CD0 + K * CLa * CLa)
    gp = math.asin(min(D / max(W - Tr_need, 1e-3 * W), 1.0))
    gam = min(gp, math.radians(gamma_app))
    s = air_distance(Vf, gam, t) + brake_distance(g, t, Vtd, 0.0, 0.0, rho)
    Tr_av = float(rotor_thrust(P_rot, Va, A, rho, t)) / kd
    P_app = P_rot * min(Tr_need / max(Tr_av, 1.0), 1.0) ** 1.5
    return s, dict(mode="rolling", gamma=math.degrees(gam), P_app=P_app,
                   t=min(500 * FT / (Va * math.sin(gam)), 120.0))


def vt_lift_power(g, cfg, t, P_push, rho):
    """Required lift power (all lanes).  Heliport: HOGE with download and a
    2.5 m/s vertical climb [L].  Runway: smallest power for 300 ft / 50 ft."""
    Ph = hover_power(t.k_download * g["W"], g["A_rot"], rho, t)
    if cfg.heli:
        vh = math.sqrt(t.k_download * g["W"] / (2 * rho * g["A_rot"]))
        x = t.vz_TO / (2 * vh)
        return Ph * (x + math.sqrt(x * x + 1)), Ph
    f = lambda P: max(vt_takeoff(g, t, P, P_push, rho)[0], vt_landing(g, t, P, rho)[0]) - REQ.s_TO
    # hover-capable (T_static = k_download W) is the natural upper bound: vertical
    # landing, near-vertical take-off.  Only search below it if a wing-borne
    # (rotor-assisted) landing can already meet 300 ft with less power.
    P_v = Ph * 1.02 ** 1.5 * 1.001                # static thrust 2 % above W: vertical take-off
    if f(0.97 * Ph) > 0:                          # needs (almost) hover power anyway -> use it
        return P_v, Ph                            # for a vertical take-off too
    lo, hi = 0.5 * Ph, 0.97 * Ph
    if f(lo) <= 0:
        return lo, Ph
    for _ in range(6):                            # bisection, ~0.7 % of hover power
        mid = 0.5 * (lo + hi)
        lo, hi = (lo, mid) if f(mid) <= 0 else (mid, hi)
    return hi, Ph


# =============================================================================
#  STRUCTURE
# =============================================================================
def load_factor(W, S, AR, V, rho):
    """FAR 23 manoeuvre n and Pratt gust n at V_C (Ue = 50 ft/s), n_ult = 1.5 max."""
    W_lb = W / G / LB
    n_man = min(2.1 + 24000.0 / (W_lb + 10000.0), 3.8)
    a = 2 * math.pi * AR / (2 + math.sqrt(AR ** 2 + 4))
    mu = 2 * (W / S) / (rho * math.sqrt(S / AR) * a * G)
    Kg = 0.88 * mu / (5.3 + mu)
    ws_psf = (W / S) * FT ** 2 / (LB * G)
    n_gust = 1 + Kg * a * 50.0 * V * math.sqrt(rho / 1.225) / KT / (498.0 * ws_psf)
    return n_man, n_gust, 1.5 * max(n_man, n_gust)


def wing_mass(t, W, S, AR, n_ult):
    """[R] Eq. 15.25, unswept, x composite factor."""
    Wlb, Sft = W / G / LB, S / FT ** 2
    m_lb = (0.0051 * (Wlb * n_ult) ** 0.557 * Sft ** 0.649 * AR ** 0.5 * t.t_c ** -0.4
            * (1 + t.taper) ** 0.1 * (t.f_csw * Sft) ** 0.1)
    return m_lb * LB * t.k_wing


def field_phases(cfg, t, g, x3, P_hl, P_cr, P_rot, P_push):
    """Hot & high take-off and landing: distances, battery-bus energies, peak shaft power."""
    eb, W, rho = eta_bus(t), g["W"], rho_field(t)
    if cfg.kind == "BW":
        s_TO, toi = bw_takeoff(g, t, x3, P_hl, P_cr, rho)
        s_LD, ldi = bw_landing(g, t, x3, rho)
        if toi is None:
            return None
        return dict(s_TO=s_TO, toi=toi, s_LD=s_LD, ldi=ldi, P_TO=P_hl + P_cr, P_cr_TO=P_cr,
                    E_TO=(P_hl + P_cr) / eb * (toi["t"] + 20.0), E_LD=ldi["P_bl"] / eb * ldi["t_app"])
    s_TO, toi = vt_takeoff(g, t, P_rot, P_push, rho)
    s_LD, ldi = vt_landing(g, t, P_rot, rho)
    if toi is None:
        return None
    Ph = hover_power(t.k_download * W, g["A_rot"], rho, t)
    t_tr = lambda cfgf: 3 * math.pi / 16 * 1.2 * math.sqrt(2 * W / (rho * g["S"] * CL_limit(t, cfgf))) / t.a_tr
    if toi["mode"] == "vertical":             # transition with rotor thrust W(1-(V/Vw)^2), P ~ T^1.5
        E_TO, P_TO, P_cr_TO = Ph / eb * (toi["t"] + t_tr("TO")), P_rot + 0.5 * P_push, 0.5 * P_push
    else:
        E_TO, P_TO, P_cr_TO = (P_rot + P_push) / eb * (toi["t"] + 20.0), P_rot + P_push, P_push
    E_LD = Ph / eb * (ldi["t"] + t_tr("LDG")) if ldi["mode"] == "vertical" else ldi["P_app"] / eb * ldi["t"]
    return dict(s_TO=s_TO, toi=toi, s_LD=s_LD, ldi=ldi, P_TO=P_TO, P_cr_TO=P_cr_TO, E_TO=E_TO, E_LD=E_LD)


# =============================================================================
#  SIZING LOOP
# =============================================================================
def size(cfg, scen, t, ws, AR, x3, m0=5500.0):
    """Converged design for one point (W/S, AR, x3 = blown CLmax or disk loading).
    Returns a result dict (with constraint margins) or None if it does not close."""
    V = scen.V_kt * KT
    rho_cr = rho_isa(t.h_cr)
    series = cfg.hybrid == "series"
    BW = cfg.kind == "BW"
    oei = oei_factor(cfg, t)
    eb = eta_bus(t)
    eta_th = 1.0 / (t.sfc * LHV)
    f2s = eta_th * (t.eta_gen * eb if series else t.eta_gbx)          # fuel -> shaft
    b2s = t.eta_batt * eb                                               # battery -> shaft
    cache = fp = None
    P_hl = P_cr = P_rot = P_push = 0.0
    fuel_mis = 0.04 * m0
    hist = []
    for it in range(40):
        g = geometry(cfg, t, m0, ws, AR, None if BW else x3)
        W = g["W"]
        # ---------------- cruise
        ld_cr, CL_cr = LD(g, 0.97 * W, V, rho_cr)
        T_cr = 0.97 * W / ld_cr
        eta_cr = eta_disk(t, T_cr, V, g["A_cruise"], rho_cr)
        P_crs = T_cr * V / eta_cr                                       # cruise shaft power
        # ---------------- installed propulsive power (P/W cached vs mass)
        if cache is None or abs(m0 / cache["m"] - 1) > 0.10:
            A = g["A_climb"]
            clb = max(climb_power(g, t, W, 0.0, REQ.roc_min, "clean", False, rho_slh(t), A),
                      climb_power(g, t, W, 0.040, 0.0, "TO", True, rho_field(t), A),
                      climb_power(g, t, W, 0.033, 0.0, "LDG", True, rho_field(t), A))
            oe = climb_power(g, t, W, 0.010, 0.0, "TO", False, rho_field(t), A)
            c = dict(m=m0, clb=clb / W, oe=oe / W)
            if BW:
                if cfg.n_cr:
                    Pc = max(P_crs / t.f_rating, 0.3 * clb)
                    for _ in range(3):                                   # HL <-> cruise coupling
                        Ph = bw_hl_power(g, t, x3, Pc, rho_field(t))
                        if not math.isfinite(Ph):
                            return None
                        Ph *= oei
                        Pc_new = max(P_crs / t.f_rating, clb - Ph,
                                     2 * (oe / t.k_em - Ph), oe / t.k_em - Ph * (cfg.n_hl - 1) / cfg.n_hl)
                        if abs(Pc_new - Pc) < 0.02 * Pc:
                            Pc = Pc_new
                            break
                        Pc = Pc_new
                    c.update(hl=Ph / W)
                else:
                    Ph = bw_hl_power(g, t, x3, 0.0, rho_field(t))
                    if not math.isfinite(Ph):
                        return None
                    c.update(hl=Ph * oei / W)
            else:
                Pp = max(P_crs / t.f_rating, clb, oe * t.push_lanes / (t.push_lanes - 1) / t.k_em)
                Pr, Ph_ = vt_lift_power(g, cfg, t, Pp, rho_field(t))
                if not math.isfinite(Pr):
                    return None
                Pr = max(Pr, Ph_ * oei) if cfg.heli else Pr * oei   # heliport: climb or lane-out hover
                c.update(rot=Pr / W)
            cache = c
        clb, oe = cache["clb"] * W, cache["oe"] * W
        if BW:
            P_hl = cache["hl"] * W
            if cfg.n_cr:
                P_cr = max(P_crs / t.f_rating, clb - P_hl, 2 * (oe / t.k_em - P_hl),
                           oe / t.k_em - P_hl * (cfg.n_hl - 1) / cfg.n_hl, 0.0)
            else:
                P_cr = 0.0
                P_hl = max(P_hl, P_crs / t.f_rating, clb, oe * cfg.n_hl / (cfg.n_hl - 1) / t.k_em)
        else:
            P_push = max(P_crs / t.f_rating, clb, oe * t.push_lanes / (t.push_lanes - 1) / t.k_em)
            P_rot = cache["rot"] * W
        # ---------------- turbine rating (cruise at <= f_rating of rated power)
        if series:
            P_ts = (P_crs / eb + t.P_aux) / t.eta_gen / lapse(t, rho_cr) / t.f_rating
        else:
            P_ts = (P_crs + t.P_aux / (t.eta_mot * t.eta_inv)) / t.eta_gbx / lapse(t, rho_cr) / t.f_rating
        # ---------------- field phases (distances, energies, peak power ~ W at fixed W/S)
        if fp is None or fp["m"] != cache["m"]:
            fp = field_phases(cfg, t, g, x3, P_hl, P_cr, P_rot, P_push)
            if fp is None:
                return None
            fp["m"] = cache["m"]; fp["W"] = W
        k_W = W / fp["W"]
        E_TO, E_LD, P_TO_shaft, P_cr_TO = (fp["E_TO"] * k_W, fp["E_LD"] * k_W,
                                           fp["P_TO"] * k_W, fp["P_cr_TO"] * k_W)
        # ---------------- battery power: turbine out / one segment out
        P_peak = P_TO_shaft / eb + t.P_aux
        P_ts_f = P_ts * lapse(t, rho_field(t))
        if series:
            P_seg = P_peak - P_ts_f * t.eta_gen
        else:
            P_seg = P_peak - min(P_ts_f * t.eta_gbx, P_cr_TO) / eb
        m_bP = max(P_peak, P_seg * cfg.n_seg / (cfg.n_seg - 1)) / t.p_pack
        # ---------------- mission: climb (turbine + battery assist)
        t_cl = t.h_cr / REQ.roc_min; s_cl = t.v_climb * t_cl / NMI
        rho_m = rho_isa(t.h_cr / 2)
        ld_cl, _ = LD(g, W, t.v_climb, rho_m)
        T_cl = W / ld_cl + W * REQ.roc_min / t.v_climb
        P_cl = T_cl * t.v_climb / eta_disk(t, T_cl, t.v_climb, g["A_climb"], rho_m)
        P_ts_cl = P_ts * lapse(t, rho_m)
        if series:
            need = (P_cl / eb + t.P_aux) / t.eta_gen
            E_cl_batt = max(need - P_ts_cl, 0.0) * t.eta_gen * t_cl / t.eta_batt
        else:
            need = (P_cl + t.P_aux / (t.eta_mot * t.eta_inv)) / t.eta_gbx
            E_cl_batt = max(need - P_ts_cl, 0.0) * t.eta_gbx / b2s * t_cl
        fuel_cl = min(need, P_ts_cl) * t.sfc * t_cl
        E_cl_full = (P_cl / eb + t.P_aux) * t_cl / t.eta_batt
        ld_de, _ = LD(g, 0.9 * W, V, rho_cr)
        s_de = (t.h_cr - t.h_desc_end) * ld_de / NMI                    # power-off glide
        E_fix = (E_TO + E_LD) / t.eta_batt + t.E_taxi
        W_el = W - fuel_mis * G
        e_m = W_el / (ld_cr * eta_cr * b2s) + t.P_aux / (V * t.eta_batt)          # J/m
        R_cr_el = max(scen.R_el - s_cl - s_de, 0.0) * NMI
        E_obj = E_fix + E_cl_full + e_m * R_cr_el                        # all-electric trip
        m_bE = E_obj / (t.e_pack * t.f_usable)
        m_bat = max(m_bE, m_bP)
        E_use = m_bat * t.e_pack * t.f_usable
        R_el_mis = max(E_use - E_fix - E_cl_batt, 0.0) / e_m / NMI
        R_fuel = max(REQ.R_total - s_cl - s_de - R_el_mis, 0.0)
        eta_f = f2s * eta_cr                                             # fuel -> thrust
        aux_fuel_rate = t.P_aux * (1 / t.eta_gen if series else 1 / (t.eta_mot * t.eta_inv * t.eta_gbx)) * t.sfc
        W1 = W - fuel_cl * G
        W2 = W1 * math.exp(-R_fuel * NMI * G / (eta_f * LHV * ld_cr))   # Breguet
        fuel_mis = fuel_cl + (W1 - W2) / G + aux_fuel_rate * R_fuel * NMI / V
        R_res = t.R_alt * NMI + V * t.t_res
        W_end = W - fuel_mis * G
        fuel_res = W_end / G * (math.exp(R_res * G / (eta_f * LHV * ld_cr)) - 1) + aux_fuel_rate * R_res / V
        fuel = (fuel_mis + fuel_res) * (1 + t.f_trapped)
        # ---------------- masses
        n_man, n_gust, n_ult = load_factor(W, g["S"], AR, V, rho_cr)
        k_m = 1 / t.sp_mot + 1 / t.sp_inv
        if BW:
            m_mot = (P_hl + P_cr) * k_m
            m_prop = (cfg.n_cr * t.k_prop * t.D_cr ** 2
                      + cfg.n_hl * (t.k_prop * g["D_hl"] ** 2 + t.m_hl_nac + (0.0 if cfg.n_cr else t.m_vp)))
        else:
            m_mot = (P_rot * (1 + t.k_lane * (cfg.lanes - 1)) + 1.10 * P_push) * k_m
            m_prop = (cfg.n_rot * t.m_rotor4 * (g["D_rot"] / 4) ** 2.2 + 2 * t.k_boom * g["l_boom"]
                      + t.k_prop * t.D_push ** 2)
        if series:
            m_pg = P_ts / t.sp_ts + P_ts * t.eta_gen * (1 / t.sp_gen + 1 / t.sp_inv)
        else:
            m_pg = P_ts / t.sp_ts + P_ts / t.sp_gbx
        parts = dict(
            payload=REQ.n_occ * REQ.m_occ,
            wing=wing_mass(t, W, g["S"], AR, n_ult),
            fuselage=t.rho_fus * g["Sw_fus"] * t.k_fus,
            tails=t.rho_tail * (g["S_ht"] + g["S_vt"]) * t.k_tail,
            gear=t.f_gear * m0 * t.k_gear,
            all_else=t.f_else * m0,
            motors_inv=m_mot * (1 + t.f_cool),
            turbo_gen=m_pg * (1 + t.f_cool),
            props_rotors=m_prop,
            HV_system=t.m_HV + cfg.n_seg * t.m_seg,
            battery=m_bat,
            fuel=fuel)
        m_new = sum(parts.values())
        if not math.isfinite(m_new) or m_new > 25000.0:
            return None
        gap = m_new - m0
        if abs(gap) < 0.5:
            if abs(m_new / cache["m"] - 1) > 0.010:                      # power/weight from a stale mass:
                cache = None                                             # refresh once, keep iterating
                hist.clear()
                m0 = m_new
                continue
            m0 = m_new
            break
        hist.append((m0, gap))
        if len(hist) >= 2 and hist[-1][0] != hist[-2][0]:               # secant
            (ma, ga), (mb, gb) = hist[-2], hist[-1]
            slope = (gb - ga) / (mb - ma)
            m_next = mb - gb / slope if slope < -0.05 else mb + 0.6 * gb
        else:
            m_next = m0 + 0.6 * gap
        m0 = min(max(m_next, 0.6 * m0), 1.6 * m0)
    else:
        return None
    fp = field_phases(cfg, t, geometry(cfg, t, m0, ws, AR, None if BW else x3), x3, P_hl, P_cr, P_rot, P_push)
    if fp is None:
        return None
    s_TO, toi, s_LD, ldi = fp["s_TO"], fp["toi"], fp["s_LD"], fp["ldi"]
    # ---------------- constraint margins (>= 0 ok)
    ck = dict(MTOW=1 - m0 / REQ.mtow_max,
              TO_300ft=1 - s_TO / REQ.s_TO,
              LD_300ft=1 - min(s_LD, 1e4) / REQ.s_LD,
              WS=1 - ws / REQ.ws_max,
              AR=1 - AR / REQ.AR_max)
    if not BW:
        ck["rotor_fit"] = g["fit"]
    r = dict(cfg=cfg, scen=scen, ws=ws, AR=AR, x3=x3, mtow=m0, g=g, parts=parts,
             P_hl=P_hl, P_cr=P_cr, P_rot=P_rot, P_push=P_push, P_ts=P_ts, P_peak=P_peak,
             ld_cr=ld_cr, CL_cr=CL_cr, eta_cr=eta_cr, m_bE=m_bE, m_bP=m_bP, E_use=E_use,
             R_el_mis=R_el_mis, R_fuel=R_fuel, fuel_mis=fuel_mis, fuel_res=fuel_res,
             s_TO=s_TO, s_LD=s_LD, to=toi, ld=ldi, n_ult=n_ult, checks=ck,
             ok=all(v >= -1e-9 for v in ck.values()))
    r["viol"] = sum(-v for v in ck.values() if v < 0)
    if not BW:
        rho = rho_field(t)
        Ph = hover_power(t.k_download * W, g["A_rot"], rho, t)
        r["heli"] = dict(MTOW=1 - m0 / t.heli_mtow, D=1 - g["ctrl_D"] / t.heli_D,
                         HOGE_OEI=P_rot / (Ph * max(1.0, oei_factor(cfg, t))) - 1)
    return r


# =============================================================================
#  OPTIMISER: coarse grid + compass search (continuous), per config/scenario
# =============================================================================
DL_MAX = 1000.0      # N/m^2 disk-loading limit (downwash/outwash, noise; ~tilt-rotor class) - assumption
GRID = dict(BW=dict(ws=(400, 600, 900, 1300, 1900, 2800, 4000), AR=(10, 14, 18), x3=(4.5, 6.0, 7.5, 9.0)),
            VT=dict(ws=(900, 1400, 2100, 3100, 4400), AR=(10, 14, 18), x3=(300, 500, 750, 1000)))
GRID_FAST = dict(BW=dict(ws=(500, 900, 1600, 2800, 4200), AR=(12, 18), x3=(5.0, 7.0, 9.0)),
                 VT=dict(ws=(1000, 1800, 3000, 4400), AR=(12, 18), x3=(350, 650, 1000)))
BOUNDS = dict(BW=((300.0, REQ.ws_max), (6.0, REQ.AR_max), (REQ.CLbl_min, REQ.CLbl_max)),
              VT=((500.0, REQ.ws_max), (6.0, REQ.AR_max), (150.0, DL_MAX)))


def score(r):
    """Feasible designs by MTOW; infeasible ones behind them, least violation
    (rounded, so the optimiser does not chase meaningless tiny gains) first."""
    if r is None:
        return (2, 0.0, 1e9)
    if r["ok"]:
        return (0, 0.0, r["mtow"])
    return (1, round(r["viol"], 2), r["mtow"])


def optimise(cfg, scen, t, fast=False, seeds=()):
    """Grid scan, then compass search from the two best distinct starting points
    (grid points or sibling-configuration optima passed as seeds)."""
    grid = (GRID_FAST if fast else GRID)[cfg.kind]
    bnd = BOUNDS[cfg.kind]
    logx3 = cfg.kind == "VT"
    enc = lambda r: (math.log(r["ws"]), r["AR"], math.log(r["x3"]) if logx3 else r["x3"])
    dec = lambda x: (math.exp(x[0]), x[1], math.exp(x[2]) if logx3 else x[2])
    cands, m_guess, n_eval = [], 5500.0, 0
    pts = [(float(ws), float(AR), float(x3)) for x3 in grid["x3"] for AR in grid["AR"] for ws in grid["ws"]]
    pts += [(r["ws"], r["AR"], r["x3"]) for r in seeds]
    for ws, AR, x3 in pts:
        r = size(cfg, scen, t, ws, AR, x3, m_guess)
        n_eval += 1
        if r is not None:
            m_guess = r["mtow"]
            cands.append(r)
    if not cands:
        return None, n_eval
    cands.sort(key=score)
    starts = [cands[0]]
    for r in cands[1:]:                            # second start: best point not next to the first
        if abs(math.log(r["ws"] / starts[0]["ws"])) > 0.3 or abs(r["x3"] / starts[0]["x3"] - 1) > 0.3:
            starts.append(r)
            break
    best = cands[0]
    budget = (60 if fast else 90) // len(starts)
    for r0 in starts:
        cur, x, used = r0, list(enc(r0)), 0
        step = [math.log(1.25), 2.0, math.log(1.25) if logx3 else 0.75]
        for _ in range(2 if fast else 3):
            improved = True
            while improved and used < budget:
                improved = False
                for i in range(3):
                    for sgn in (1, -1):
                        y = list(x); y[i] += sgn * step[i]
                        v = list(dec(y)); v[i] = min(max(v[i], bnd[i][0]), bnd[i][1])
                        r = size(cfg, scen, t, v[0], v[1], v[2], cur["mtow"])
                        used += 1
                        if score(r) < score(cur):
                            cur, x, improved = r, list(enc(r)), True
                            break
                    if improved:
                        break
            step = [st / 2 for st in step]
        n_eval += used
        if score(cur) < score(best):
            best = cur
    return best, n_eval


def config_groups():
    """Configurations that differ only in hybrid type, battery segments or heliport
    mode are optimised together; each one seeds the others (robust + fast)."""
    groups = {}
    for c in all_configs():
        key = (c.kind, c.n_hl, c.n_cr, c.n_rot, c.lanes)
        groups.setdefault(key, []).append(c)
    return list(groups.values())


def _job(args):
    cfgs, scen, t, fast = args
    out, found, n_tot = [], [], 0
    for k, c in enumerate(cfgs):                   # full grid for the first, small grid + seeds after
        r, n = optimise(c, scen, t, fast or k > 0, seeds=found)
        n_tot += n
        if r is not None:
            found.append(r)
        out.append((c, scen, r))
    # second pass: re-seed the early members with the later optima
    for k, (c, sc, r) in enumerate(out):
        others = [x for x in found if x is not r]
        r2, n = optimise(c, scen, t, True, seeds=others)
        n_tot += n
        if r2 is not None and score(r2) < score(r):
            out[k] = (c, sc, r2)
    return out, n_tot


# =============================================================================
#  POST-PROCESSING
# =============================================================================
def landing_sensitivity(r, t, gammas=(12.0, 15.0, 20.0, 25.0)):
    """Landing distance of a converged design for other approach-angle limits
    - shows what would enable the 300 ft landing."""
    g, cfg = r["g"], r["cfg"]
    out = {}
    for gm in gammas:
        if cfg.kind == "BW":
            s, i = bw_landing(g, t, r["x3"], rho_field(t), gm)
        else:
            s, i = vt_landing(g, t, r["P_rot"], rho_field(t), gm)
        out[gm] = s / FT
    return out


def bw_ws_limit(r, t, gamma):
    """Largest W/S at which the blown wing (same MTOW, AR, blown CLmax 9) lands in
    300 ft over 50 ft at the hot & high field for a given approach-angle limit,
    and the cruise L/D that W/S would leave.  Explains why the BW cannot close."""
    cfg, m0, AR = r["cfg"], r["mtow"], r["AR"]
    ok = lambda ws: bw_landing(geometry(cfg, t, m0, ws, AR), t, REQ.CLbl_max, rho_field(t), gamma)[0] <= REQ.s_LD
    lo, hi = 50.0, REQ.ws_max
    if not ok(lo):
        return None, None
    for _ in range(30):
        mid = math.sqrt(lo * hi)
        lo, hi = (mid, hi) if ok(mid) else (lo, mid)
    g = geometry(cfg, t, m0, lo, AR)
    return lo, LD(g, 0.97 * g["W"], r["scen"].V_kt * KT, rho_isa(t.h_cr))[0]


def fmt_cfg_row(r):
    c, p = r["cfg"], r["parts"]
    x3 = f"CL{r['x3']:4.1f}" if c.kind == "BW" else f"DL{r['x3']:5.0f}"
    lift = (r["P_hl"] if c.kind == "BW" else r["P_rot"]) / 1e3
    cr = (r["P_cr"] if c.kind == "BW" else r["P_push"]) / 1e3
    bat = "E" if r["m_bE"] >= r["m_bP"] else "P"
    fail = "ok" if r["ok"] else ",".join(k for k, v in r["checks"].items() if v < 0)
    return (f"{c.name:<24s}{r['mtow']:7.0f}{r['mtow'] / LB:7.0f}{r['ws']:6.0f}{r['AR']:5.1f} {x3:<8s}"
            f"{r['g']['b']:5.1f}{lift:6.0f}{cr:5.0f}{r['P_ts'] / 1e3:5.0f}{p['battery']:6.0f}{bat}"
            f"{p['fuel']:5.0f}{r['s_TO'] / FT:6.0f}{min(r['s_LD'], 1e4) / FT:6.0f}  {fail}")


HDR = (f"{'config':<24s}{'MTOWkg':>7s}{'lb':>7s}{'W/S':>6s}{'AR':>5s} {'CL/DL':<8s}{'b m':>5s}"
       f"{'Plift':>6s}{'Pcr':>5s}{'Pts':>5s}{'batt':>6s} {'fuel':>5s}{'TOft':>6s}{'LDft':>6s}  RFP")


def make_plots(best_by, scen_list):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fams = ("BW +CR", "BW noCR", "VT runway", "VT heliport")
    cols = ("#2a78d6", "#1baf7a", "#eb6834", "#eda100")
    fig, ax = plt.subplots(figsize=(10, 5))
    x = np.arange(len(scen_list)); w = 0.2
    for k, (f, col) in enumerate(zip(fams, cols)):
        vals, hatch = [], []
        for s in scen_list:
            r = best_by.get((s, f))
            vals.append(r["mtow"] if r else np.nan)
            hatch.append(r is not None and not r["ok"])
        bars = ax.bar(x + (k - 1.5) * w, vals, w * 0.92, color=col, label=f)
        for b_, h in zip(bars, hatch):
            if h:
                b_.set_hatch("//"); b_.set_edgecolor("white")
    ax.axhline(REQ.mtow_max, color="#6b6b66", lw=1, ls="--")
    ax.text(len(scen_list) - 0.5, REQ.mtow_max, " 19,000 lb", va="bottom", ha="right", fontsize=8, color="#6b6b66")
    ax.set_xticks(x); ax.set_xticklabels([s.name for s in scen_list])
    ax.set_ylabel("MTOW [kg]")
    ax.set_title("Best design per family and scenario (hatched = a hard requirement is violated)")
    ax.legend(frameon=False, ncol=4, fontsize=8, loc="upper left")
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    ax.grid(axis="y", alpha=0.25)
    fig.tight_layout(); fig.savefig(OUT / "mtow_by_family.png", dpi=140); plt.close(fig)

    fig, axs = plt.subplots(1, len(scen_list), figsize=(15, 5), sharey=True)
    keys = ("payload", "wing", "fuselage", "tails", "gear", "all_else", "motors_inv", "turbo_gen",
            "props_rotors", "HV_system", "battery", "fuel")
    cmap = plt.get_cmap("tab20")
    for ax, s in zip(np.atleast_1d(axs), scen_list):
        bottom = np.zeros(len(fams))
        for j, k in enumerate(keys):
            v = np.array([best_by[(s, f)]["parts"][k] if best_by.get((s, f)) else 0.0 for f in fams])
            ax.bar(range(len(fams)), v, bottom=bottom, color=cmap(j), edgecolor="white", lw=0.5,
                   label=k if s is scen_list[0] else None)
            bottom += v
        ax.set_xticks(range(len(fams))); ax.set_xticklabels(fams, rotation=30, ha="right", fontsize=8)
        ax.set_title(s.name, fontsize=9)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
    np.atleast_1d(axs)[0].set_ylabel("mass [kg]")
    fig.legend(loc="upper center", ncol=6, fontsize=8, frameon=False)
    fig.tight_layout(rect=(0, 0, 1, 0.88)); fig.savefig(OUT / "mass_breakdown.png", dpi=140); plt.close(fig)


# =============================================================================
#  MAIN
# =============================================================================
def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[2])
    ap.add_argument("--fast", action="store_true", help="smaller grid")
    ap.add_argument("--plots", action="store_true", help="write PNG plots")
    ap.add_argument("--jobs", type=int, default=0, help="processes (0 = all cores)")
    ap.add_argument("--gamma", type=float, default=None, help="max wing-borne approach angle, deg")
    ap.add_argument("--h-field", type=float, default=None, help="field elevation, ft (default 5000)")
    ap.add_argument("--dT", type=float, default=None, help="field ISA temperature offset, K (default 10)")
    ap.add_argument("--verbose", action="store_true", help="print every configuration")
    a = ap.parse_args()
    t0 = time.time()
    t = TECH
    if a.gamma is not None:
        t = replace(t, gamma_app=a.gamma)
    if a.h_field is not None:
        t = replace(t, h_field=a.h_field * FT)
    if a.dT is not None:
        t = replace(t, dT_field=a.dT)
    OUT.mkdir(exist_ok=True)
    jobs = [(grp, s, t, a.fast) for s in SCENARIOS for grp in config_groups()]
    n_proc = a.jobs or os.cpu_count() or 1
    if n_proc > 1:
        with ProcessPoolExecutor(max_workers=n_proc) as ex:
            out = list(ex.map(_job, jobs))
    else:
        out = [_job(j) for j in jobs]
    res = [x for o, _ in out for x in o]
    n_eval = sum(n for _, n in out)

    print("=" * 118)
    print(" BLOWN WING vs LIFT+CRUISE VTOL  -  same mission, technology and methods")
    print(f" field: {t.h_field / FT:.0f} ft ISA+{t.dT_field * 1.8:.0f}F (rho {rho_field(t):.3f}),"
          f" 300 ft over 50 ft take-off AND landing (hard), max wing-borne approach {t.gamma_app:.0f} deg,"
          f" mu_brake {t.mu_brake}, reverse credit {t.f_rev:.0%}")
    print(f" battery {t.e_pack / WH:.0f} Wh/kg pack, {t.p_pack / 1e3:.1f} kW/kg;  400 nmi + 50 nmi alternate + 45 min;"
          f"  W/S <= {REQ.ws_max:.0f}, AR <= {REQ.AR_max:.0f}, blown CLmax {REQ.CLbl_min}-{REQ.CLbl_max}")
    print("=" * 118)

    best_by, rows = {}, []
    for s in SCENARIOS:
        rs = [r for c, sc, r in res if sc == s and r is not None]
        miss = [c.name for c, sc, r in res if sc == s and r is None]
        rs.sort(key=score)
        for r in rs:
            f = r["cfg"].family
            if score(r) < score(best_by.get((s, f))):
                best_by[(s, f)] = r
        print(f"\n SCENARIO {s.name}: all-electric {s.R_el:.0f} nmi, cruise {s.V_kt:.0f} kt")
        print(" " + HDR)
        show = rs if a.verbose else [best_by[(s, f)] for f in ("BW +CR", "BW noCR", "VT runway", "VT heliport")
                                     if (s, f) in best_by]
        for r in show:
            print(" " + fmt_cfg_row(r))
        if miss:
            print(f"   no closed design: {', '.join(miss)}")
        for r in rs:
            c = r["cfg"]; p = r["parts"]
            rows.append(dict(scenario=s.name, config=c.name, family=c.family, kind=c.kind,
                             n_hl=c.n_hl, n_cr=c.n_cr, n_rot=c.n_rot, lanes=c.lanes, hybrid=c.hybrid,
                             n_seg=c.n_seg, heli=c.heli, feasible=r["ok"],
                             violated=";".join(k for k, v in r["checks"].items() if v < 0),
                             MTOW_kg=round(r["mtow"], 1), MTOW_lb=round(r["mtow"] / LB),
                             WS=round(r["ws"]), AR=round(r["AR"], 2),
                             CLmax_blown=round(r["x3"], 2) if c.kind == "BW" else "",
                             disk_loading=round(r["x3"]) if c.kind == "VT" else "",
                             span_m=round(r["g"]["b"], 2), LD_cruise=round(r["ld_cr"], 2),
                             P_lift_kW=round((r["P_hl"] if c.kind == "BW" else r["P_rot"]) / 1e3),
                             P_cruise_kW=round((r["P_cr"] if c.kind == "BW" else r["P_push"]) / 1e3),
                             P_turbine_kW=round(r["P_ts"] / 1e3),
                             battery_kg=round(p["battery"]), battery_sized_by="energy" if r["m_bE"] >= r["m_bP"] else "power",
                             fuel_kg=round(p["fuel"]), TO_ft=round(r["s_TO"] / FT), LD_ft=round(min(r["s_LD"], 1e4) / FT),
                             **{f"m_{k}": round(v) for k, v in p.items()}))

    # ---------------- head-to-head
    print("\n" + "=" * 118)
    print(" HEAD-TO-HEAD: lightest design per family (feasible first, else least violation)")
    print("=" * 118)
    print(f" {'scenario':<14s}" + "".join(f"{f:>26s}" for f in ("BW +CR", "BW noCR", "VT runway", "VT heliport")))
    for s in SCENARIOS:
        line = f" {s.name:<14s}"
        for f in ("BW +CR", "BW noCR", "VT runway", "VT heliport"):
            r = best_by.get((s, f))
            line += f"{'-':>26s}" if r is None else f"{r['mtow']:7.0f} kg {'OK ' if r['ok'] else 'NOK'} {r['cfg'].name[:12]:>12s}"
        print(line)

    # ---------------- what drives the result
    print("\n DRIVERS (scenario " + SCENARIOS[-1].name + ")")
    s = SCENARIOS[-1]
    for f in ("BW +CR", "BW noCR", "VT runway", "VT heliport"):
        r = best_by.get((s, f))
        if not r:
            continue
        sens = landing_sensitivity(r, t)
        ld = r["ld"]
        extra = (f", approach path physically {ld['gamma_phys']:.1f} deg (D - T_blow)" if r["cfg"].kind == "BW"
                 else f", landing mode {ld['mode']}")
        if r["cfg"].kind == "BW":
            lim = [(gm, *bw_ws_limit(r, t, gm)) for gm in (12.0, 20.0, 30.0)]
            print(f"  {f:<12s} 300-ft landing needs W/S <= "
                  + ", ".join(f"{w:.0f} N/m2 (cruise L/D {l:.1f}) at {gm:.0f} deg" if w else f"n/a at {gm:.0f} deg"
                              for gm, w, l in lim)
                  + f"; this design: W/S {r['ws']:.0f}, L/D {r['ld_cr']:.1f}")
        print(f"  {f:<12s} landing ft for approach-angle limit "
              + ", ".join(f"{k:.0f} deg: {v:.0f}" for k, v in sens.items()) + extra)
        if r["cfg"].kind == "VT":
            h = r["heli"]
            print(f"  {'':<12s} heliport envelope margins (optional objective): MTOW {h['MTOW']:+.2f},"
                  f" controlling dim. {r['g']['ctrl_D']:.1f} m ({h['D']:+.2f}), HOGE lane-out {h['HOGE_OEI']:+.2f}")
    print("\n Effect of the architecture options (mean MTOW change, pairs of otherwise equal configs,"
          " both feasible, all scenarios; BW pairs only if a BW closes):")
    def delta(pred_a, key):
        d = []
        idx = {(r["scenario"], r["config"]): r for r in rows if r["feasible"]}
        for r in rows:
            if r["feasible"] and pred_a(r):
                other = key(r)
                if (r["scenario"], other) in idx:
                    d.append(idx[(r["scenario"], other)]["MTOW_kg"] - r["MTOW_kg"])
        return (np.mean(d), len(d)) if d else (float("nan"), 0)
    for lab, pa, kf in (
            ("battery 2 -> 4 segments ", lambda r: r["n_seg"] == 2, lambda r: r["config"].replace("-B2", "-B4")),
            ("series -> parallel      ", lambda r: r["hybrid"] == "series",
             lambda r: r["config"].replace("-ser-", "-par-")),
            ("BW: +2CR -> no CR       ", lambda r: r["kind"] == "BW" and r["n_cr"] == 2 and r["hybrid"] == "series",
             lambda r: r["config"].replace("+2CR", "-noCR")),
            ("VT: 2 -> 3 lanes        ", lambda r: r["kind"] == "VT" and r["lanes"] == 2,
             lambda r: r["config"].replace("R2L", "R3L")),
            ("VT: 4 -> 6 rotors       ", lambda r: r["kind"] == "VT" and r["n_rot"] == 4,
             lambda r: r["config"].replace("VT4", "VT6")),
            ("VT: runway -> heliport  ", lambda r: r["kind"] == "VT" and not r["heli"],
             lambda r: r["config"] + "-HELI")):
        m, n = delta(pa, kf)
        print(f"   {lab}{m:+8.0f} kg  ({n} pairs)")
    print("\n Blown wing best effort (least violation), mean over scenarios:")
    for ncr in (2, 0):
        for n_hl in (6, 8, 10):
            sel = [r for r in rows if r["kind"] == "BW" and r["n_hl"] == n_hl and r["n_cr"] == ncr]
            if sel:
                print(f"   BW{n_hl:2d} {'+2 cruise props' if ncr else 'no cruise props'}: TO {np.mean([x['TO_ft'] for x in sel]):4.0f} ft,"
                      f" LD {np.mean([x['LD_ft'] for x in sel]):4.0f} ft, MTOW {np.mean([x['MTOW_kg'] for x in sel]):6.0f} kg"
                      f"  (feasible: {sum(x['feasible'] for x in sel)}/{len(sel)})")
    with (OUT / "all_designs.csv").open("w", newline="", encoding="utf-8") as fh:
        wr = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        wr.writeheader(); wr.writerows(rows)
    if a.plots:
        make_plots(best_by, list(SCENARIOS))
    print(f"\n {len(res)} config/scenario optimisations, {n_eval} sizing runs, {n_proc} processes;"
          f" output in {OUT};  run time {time.time() - t0:.1f} s")


if __name__ == "__main__":
    main()
