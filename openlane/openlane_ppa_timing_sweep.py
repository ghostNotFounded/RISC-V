#!/usr/bin/env python3
"""
OpenLane PPA & Timing Closure Sweeper
====================================
Automates OpenLane ASIC physical design flow:
1. Utilization & Density PPA Sweeps (FP_CORE_UTIL)
2. Iterative Timing Closure (Clock Period Search for Fmax)
3. Automated Metrics Extraction & Signoff Power Breakdown

Usage:
  python3 openlane_ppa_timing_sweep.py --design-dir ./ --sweep-util 30,45,60,75
  python3 openlane_ppa_timing_sweep.py --design-dir ./ --timing-search --init-period 15.0
"""

import os
import sys
import json
import csv
import glob
import subprocess
import argparse


def parse_sta_summary(report_path):
    """
    Parses OpenSTA / OpenLane summary.rpt file to extract Setup WNS, TNS, and Hold WNS.
    """
    results = {'setup_wns': None, 'setup_tns': None, 'hold_wns': None}
    if not os.path.exists(report_path):
        return results

    with open(report_path, 'r') as f:
        content = f.read()

    lines = content.split('\n')
    current_section = None
    for line in lines:
        line_clean = line.strip()
        if 'report_tns' in line_clean:
            current_section = 'tns'
        elif 'report_wns' in line_clean:
            current_section = 'wns'
        elif 'report_worst_slack -max' in line_clean:
            current_section = 'setup_slack'
        elif 'report_worst_slack -min' in line_clean:
            current_section = 'hold_slack'
        elif line_clean.startswith('tns ') and current_section == 'tns':
            results['setup_tns'] = float(line_clean.split()[-1])
        elif line_clean.startswith('wns ') and current_section == 'wns':
            results['setup_wns'] = float(line_clean.split()[-1])
        elif line_clean.startswith('worst slack ') and current_section == 'setup_slack':
            results['setup_wns'] = float(line_clean.split()[-1])
        elif line_clean.startswith('worst slack ') and current_section == 'hold_slack':
            results['hold_wns'] = float(line_clean.split()[-1])

    return results


def parse_power_report(power_rpt_path):
    """
    Parses OpenLane signoff power.rpt file to extract Total, Internal, Switching, and Leakage Power.
    """
    p_data = {'total_power_mw': 0.0, 'internal_power_mw': 0.0, 'switching_power_mw': 0.0, 'leakage_power_nw': 0.0}
    if not os.path.exists(power_rpt_path):
        return p_data

    with open(power_rpt_path, 'r') as f:
        lines = f.readlines()

    # Look for Total row in Typical Corner or report table
    for i, line in enumerate(lines):
        if line.strip().startswith('Total') and ('100.0%' in line or i > 0):
            parts = line.strip().split()
            try:
                p_data['internal_power_mw'] = float(parts[1]) * 1000.0
                p_data['switching_power_mw'] = float(parts[2]) * 1000.0
                p_data['leakage_power_nw'] = float(parts[3]) * 1e9
                p_data['total_power_mw'] = float(parts[4]) * 1000.0
                break
            except (ValueError, IndexError):
                continue
    return p_data


def run_openlane_flow(design_dir, config_json_path, run_tag, openlane_cmd=None):
    """
    Executes the OpenLane flow for a specific run tag.
    """
    if openlane_cmd is None:
        # Search for flow.tcl in current directory, /openlane, or parent directories
        candidates = [
            "./flow.tcl",
            "/openlane/flow.tcl",
            os.path.join(os.path.dirname(os.path.abspath(design_dir)), "../../flow.tcl"),
            os.path.expanduser("~/OpenLane/flow.tcl")
        ]
        for c in candidates:
            if os.path.exists(c):
                openlane_cmd = c
                break
        if openlane_cmd is None:
            openlane_cmd = "./flow.tcl"

    print(f"\n[OpenLane Automation] Launching run: '{run_tag}' using '{openlane_cmd}'...")
    
    cmd = [openlane_cmd, "-design", design_dir, "-tag", run_tag]
    
    try:
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
        for line in process.stdout:
            if any(k in line for k in ["STEP", "Running", "ERROR", "WNS", "DRC", "LVS", "Successful", "Routing", "routing", "Iteration", "violations"]):
                print(f"  [{run_tag}] {line.strip()}", flush=True)
        process.wait()
        return process.returncode == 0
    except Exception as e:
        print(f"  [ERROR] Failed to execute OpenLane: {e}")
        return False


def update_config(config_path, updates):
    """
    Updates key-value pairs in OpenLane config.json.
    """
    with open(config_path, 'r') as f:
        cfg = json.load(f)
    
    cfg.update(updates)
    
    with open(config_path, 'w') as f:
        json.dump(cfg, f, indent=2)
    print(f"  [Config Updated] {updates}")


def sweep_utilization(design_dir, util_list, init_clock_period=15.0, density=None, auto_density=False):
    """
    Sweeps FP_CORE_UTIL values and collects PPA metrics.
    """
    config_file = os.path.join(design_dir, "config.json")
    results = []

    for util in util_list:
        run_tag = f"run_util{util}"
        
        cfg_updates = {"FP_CORE_UTIL": util, "CLOCK_PERIOD": init_clock_period, "ROUTING_CORES": 8}
        if density is not None:
            cfg_updates["PL_TARGET_DENSITY"] = density
        elif auto_density:
            # Scale PL_TARGET_DENSITY with FP_CORE_UTIL (e.g. 30% util -> 0.35 density, 60% util -> 0.65 density)
            scaled_density = round(min(0.85, (util / 100.0) + 0.05), 2)
            cfg_updates["PL_TARGET_DENSITY"] = scaled_density

        print(f"\n" + "="*70)
        print(f"SWEEPING CORE UTILIZATION: {util}% -> Tag: {run_tag}")
        print("="*70)

        # 1. Update config.json
        update_config(config_file, cfg_updates)

        # 2. Run OpenLane Flow
        success = run_openlane_flow(design_dir, config_file, run_tag)

        # 3. Extract Metrics from Run Directory
        run_dir = os.path.join(design_dir, "runs", run_tag)
        metrics_csv = os.path.join(run_dir, "reports", "metrics.csv")
        
        row_res = {
            'run_tag': run_tag,
            'util_config': util,
            'status': 'PASSED' if success else 'FAILED',
            'core_area_mm2': 0.0,
            'die_area_mm2': 0.0,
            'total_power_mw': 0.0,
            'internal_power_mw': 0.0,
            'switching_power_mw': 0.0,
            'leakage_power_nw': 0.0,
            'setup_wns': None
        }

        # Parse metrics.csv if available
        if os.path.exists(metrics_csv):
            with open(metrics_csv, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row.get('CoreArea_um^2'):
                        row_res['core_area_mm2'] = float(row['CoreArea_um^2']) / 1e6
                    if row.get('DIEAREA_mm^2'):
                        row_res['die_area_mm2'] = float(row['DIEAREA_mm^2'])

        # Parse Signoff Power Report
        power_rpt = glob.glob(os.path.join(run_dir, "reports", "signoff", "**", "*nom*.power.rpt"), recursive=True)
        if power_rpt:
            p_data = parse_power_report(power_rpt[0])
            row_res.update(p_data)

        # Parse Signoff STA Summary
        sta_summary = glob.glob(os.path.join(run_dir, "reports", "signoff", "**", "*nom*.summary.rpt"), recursive=True)
        if sta_summary:
            sta_data = parse_sta_summary(sta_summary[0])
            row_res['setup_wns'] = sta_data['setup_wns']

        results.append(row_res)
        wns_str = f"{row_res['setup_wns']:.2f}" if row_res['setup_wns'] is not None else "N/A"
        print(f"\n[Completed {run_tag}] Status: {row_res['status']} | Core Area: {row_res['core_area_mm2']:.3f} mm² | Power: {row_res['total_power_mw']:.2f} mW | Setup WNS: {wns_str} ns\n", flush=True)

    # Print Summary Table
    print("\n" + "="*80)
    print("PPA SWEEP SUMMARY RESULTS")
    print("="*80)
    print(f"{'Run Tag':<12} | {'Status':<7} | {'Core (mm²)':<10} | {'Total Power (mW)':<16} | {'Switching (mW)':<14} | {'Setup WNS (ns)'}")
    print("-" * 80)
    for r in results:
        wns_str = f"{r['setup_wns']:.2f}" if r['setup_wns'] is not None else "N/A"
        print(f"{r['run_tag']:<12} | {r['status']:<7} | {r['core_area_mm2']:<10.3f} | {r['total_power_mw']:<16.2f} | {r['switching_power_mw']:<14.2f} | {wns_str}")

    return results


def timing_closure_search(design_dir, start_period=15.0, target_margin_ns=0.1, max_iterations=5, util=None, density=None):
    """
    Iterative timing sweep to find maximum operational frequency (Fmax).
    Steps CLOCK_PERIOD based on setup Worst Negative Slack (WNS) until slack converges to ~0.
    """
    config_file = os.path.join(design_dir, "config.json")
    
    updates = {"CLOCK_PERIOD": start_period, "ROUTING_CORES": 8}
    if util is not None:
        updates["FP_CORE_UTIL"] = util
    if density is not None:
        updates["PL_TARGET_DENSITY"] = density
        
    update_config(config_file, updates)
    
    # Read and print current active configuration
    with open(config_file, 'r') as f:
        cfg = json.load(f)
        
    print("\n" + "="*70)
    print(f"STARTING ITERATIVE TIMING CLOSURE SEARCH")
    print(f"  • Initial Clock Period: {start_period} ns ({1000.0/start_period:.1f} MHz)")
    print(f"  • Core Utilization (FP_CORE_UTIL): {cfg.get('FP_CORE_UTIL')}%")
    print(f"  • Placement Target Density (PL_TARGET_DENSITY): {cfg.get('PL_TARGET_DENSITY')}")
    print(f"  • Synthesis Strategy: {cfg.get('SYNTH_STRATEGY')}")
    print(f"  • PDK / Std Cell Library: {cfg.get('PDK')} / {cfg.get('STD_CELL_LIBRARY')}")
    print("="*70)

    current_period = start_period

    for iteration in range(1, max_iterations + 1):
        run_tag = f"timing_step_{iteration}_{current_period:.2f}ns"
        print(f"\n--- Iteration {iteration}: Setting CLOCK_PERIOD = {current_period:.2f} ns ({1000.0/current_period:.1f} MHz) ---")
        
        # 1. Update CLOCK_PERIOD in config
        update_config(config_file, {"CLOCK_PERIOD": current_period})
        
        # 2. Run OpenLane
        run_openlane_flow(design_dir, config_file, run_tag)
        
        # 3. Read STA Summary
        run_dir = os.path.join(design_dir, "runs", run_tag)
        sta_summary = glob.glob(os.path.join(run_dir, "reports", "signoff", "**", "*rcx_sta.summary.rpt"), recursive=True)
        if not sta_summary:
            sta_summary = glob.glob(os.path.join(run_dir, "reports", "signoff", "**", "*.summary.rpt"), recursive=True)

        if not sta_summary:
            print(f"  [Warning] STA summary report not found for {run_tag}. Halting timing search.")
            break

        sta_res = parse_sta_summary(sta_summary[0])
        setup_slack = sta_res['setup_wns']

        if setup_slack is None:
            print("  [Warning] Could not extract setup slack. Halting search.")
            break

        print(f"  [STA Output] Clock Period: {current_period:.2f} ns | Setup Worst Slack: {setup_slack:+.3f} ns")

        # 4. Check Convergence
        if abs(setup_slack) <= target_margin_ns:
            fmax = 1000.0 / current_period
            print(f"\n🎉 [CONVERGED] Timing closed at CLOCK_PERIOD = {current_period:.2f} ns -> Fmax = {fmax:.2f} MHz!")
            return current_period, fmax

        # 5. Compute Next Clock Period
        next_period = round(current_period - setup_slack + target_margin_ns, 2)

        if next_period <= 1.0:
            print("  [Limit Reached] Required clock period is unrealistically small (<1ns). Stopping.")
            break

        print(f"  [Adjustment] Next target clock period: {next_period:.2f} ns ({1000.0/next_period:.1f} MHz)")
        current_period = next_period

    fmax = 1000.0 / current_period
    print(f"\n[Finished] Final tested CLOCK_PERIOD: {current_period:.2f} ns (Fmax ~ {fmax:.2f} MHz)")
    return current_period, fmax


def resolve_design_dir(path):
    """
    Resolves design-dir path across host and docker environments.
    """
    expanded = os.path.expanduser(path)
    if os.path.exists(expanded):
        return expanded
    
    if "OpenLane/designs/" in path:
        rel = path.split("OpenLane/designs/")[-1]
        docker_candidate = os.path.join("/openlane/designs", rel)
        if os.path.exists(docker_candidate):
            return docker_candidate
        local_candidate = os.path.join("designs", rel)
        if os.path.exists(local_candidate):
            return local_candidate
            
    if os.path.exists("./config.json"):
        return "./"
        
    return path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OpenLane PPA & Timing Closure Sweep Script")
    parser.add_argument("--design-dir", default="designs/rv32i_core", help="Path to OpenLane design folder containing config.json")
    parser.add_argument("--sweep-util", type=str, help="Comma-separated utilization values (e.g., '30,45,60,75')")
    parser.add_argument("--timing-search", action="store_true", help="Perform iterative timing search for Fmax")
    parser.add_argument("--init-period", type=float, default=15.0, help="Initial clock period in ns")
    parser.add_argument("--util", type=int, help="Override FP_CORE_UTIL for timing search (e.g. 60)")
    parser.add_argument("--density", type=float, help="Override PL_TARGET_DENSITY for timing search (e.g. 0.78)")

    parser.add_argument("--auto-density", action="store_true", help="Automatically scale PL_TARGET_DENSITY with FP_CORE_UTIL during sweeps")

    args = parser.parse_args()

    design_dir = resolve_design_dir(args.design_dir)
    print(f"[OpenLane Sweeper] Using design directory: '{design_dir}'")

    if args.sweep_util and args.timing_search:
        print("\n🚀 [COMBINED MODE] Running Iterative Timing Search across Utilization Levels...")
        utils = [int(x.strip()) for x in args.sweep_util.split(",")]
        combined_results = {}
        for u in utils:
            print(f"\n" + "█"*75)
            print(f"  UTILIZATION LEVEL: {u}%")
            print("█"*75)
            calc_density = args.density
            if args.auto_density and calc_density is None:
                calc_density = round(min(0.85, (u / 100.0) + 0.05), 2)
            period, fmax = timing_closure_search(
                design_dir, 
                start_period=args.init_period, 
                util=u, 
                density=calc_density
            )
            combined_results[u] = {'period_ns': period, 'fmax_mhz': fmax}
            
        print("\n" + "="*80)
        print("COMBINED UTILIZATION & TIMING SEARCH RESULTS")
        print("="*80)
        print(f"{'Util (%)':<10} | {'Closed Period (ns)':<20} | {'Achieved Fmax (MHz)':<22}")
        print("-" * 80)
        for u, res in combined_results.items():
            print(f"{u:<10} | {res['period_ns']:<20.2f} | {res['fmax_mhz']:<22.2f}")
    elif args.sweep_util:
        utils = [int(x.strip()) for x in args.sweep_util.split(",")]
        sweep_utilization(design_dir, utils, init_clock_period=args.init_period, density=args.density, auto_density=args.auto_density)
    elif args.timing_search:
        timing_closure_search(design_dir, start_period=args.init_period, util=args.util, density=args.density)


