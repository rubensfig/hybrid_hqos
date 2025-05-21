#!/usr/bin/python3
# -*- coding: utf-8 -*-

import warnings

warnings.simplefilter(action="ignore", category=FutureWarning)
warnings.simplefilter(action="ignore", category=UserWarning)

import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import matplotlib.patches as mpatches
import matplotlib as mat
import os
import seaborn as sns
import numpy as np
import matplotlib.ticker as mticker
import ast
import json
from matplotlib import colors
from PIL import ImageColor
import glob
import matplotlib.ticker as ticker
import pathlib
import scipy.stats as st
from scipy.optimize import curve_fit
from scipy.stats import poisson, norm
from brokenaxes import brokenaxes

from sklearn import preprocessing
import re

import scipy.stats as st

from fitter import Fitter

def collect_csv_files(root_dir):
    """
    Traverse the directory structure to collect all CSV file paths.

    Args:
    root_dir (str): The root directory where experiments are stored.

    Returns:
    csv_files (list): List of file paths to all CSV files found.
    """
    csv_files = []

    # Walk through all folders and subfolders
    for dirpath, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.endswith(".csv"):
                csv_files.append(os.path.join(dirpath, filename))

    return csv_files


def clean_column_names(columns, maximum):
    new_columns = []
    interval_pattern = re.compile(
        r"(\d+\.?\d*)[^\d]+([^\s]+)us"
    )  # Pattern to match intervals

    for col in columns:
        if isinstance(col, str):  # Ensure col is a string before processing
            match = interval_pattern.search(col)
            if match:
                start, end = match.groups()
                if end == "x":
                    end = maximum
                new_columns.append(f"{start}-{end}")  # Example: '0-20'
            else:
                new_columns.append(col)

    return new_columns


def parse_and_merge_csv(csv_files):
    """
    Parse all CSV files and merge them into a single DataFrame,
    handling different column structures by filling NaN for missing columns.

    Args:
    csv_files (list): List of file paths to the CSV files.

    Returns:
    merged_df (pd.DataFrame): Merged DataFrame with all data from CSV files.
    """
    dataframes = []

    for file in csv_files:
        # Extract experiment details from the directory structure
        path_parts = file.split(os.sep)
        experiment = path_parts[
            -4
        ]  # Assuming experiment/level/packet_size/output_file.csv
        level = path_parts[-3]
        packet_size = path_parts[-2]

        # Read the CSV file into a DataFrame
        df = pd.read_csv(file)

        if df.columns is None or len(df.columns) == 0:
            print(f"Warning: {file} has no column names or columns are empty.")

        # df.columns = clean_column_names(df.columns)

        # Add metadata columns to identify the experiment, level, and packet size
        df["Experiment"] = (
            experiment if "tc" not in experiment else int(experiment.strip("tc"))
        )
        df["Level"] = int(level)
        df["Packet Size"] = int(packet_size)
        df["IPv4 :Raw priority"] = df["IPv4 :Raw priority"].apply(
            lambda x: int(x[2], 16)
        )

        # Append the DataFrame to the list
        dataframes.append(df)

    # Merge all DataFrames, handling different columns by filling missing ones with NaN
    merged_df = pd.concat(dataframes, ignore_index=True, sort=False)

    return merged_df


def group_and_clean(df, maximums, groups):
    grouped_df = df.groupby(groups, as_index=False)

    f = dict()

    for index, group in grouped_df:
        # f[index] = clean_column_names(group.dropna(axis=1, how='all'))
        g = group.dropna(axis=1, how="all")
        # print(group['Cut-Through Max Latency (ns)'].max())
        # g.columns = clean_column_names(g, group['Cut-Through Max Latency (ns)'].max()/10**3)

        if index in maximums:
            max_applied = maximums[index]
        else:
            max_applied = (0, maximums[index][1], maximums[index][2])
        g.columns = clean_column_names(g, maximums[index])
        # print(g.columns)
        f[index] = g

    return f


def get_only_bins_per_flowgroup(df, column, flow_group="", negative_match=""):
    interval_pattern = re.compile(r".*-.*")  # Pattern for intervals
    interval_columns = [
        col
        for col in df.columns
        if interval_pattern.search(col) and "Latency" not in col
    ]

    if flow_group == "":
        df = df[df[column] != negative_match]
    else:
        df = df[df[column] == flow_group]
    return df[interval_columns]

def get_median_tail(
    ranges, cumsum
):  # Given cumulative sum data and corresponding intervals
    # Use lambda to split the string and convert to tuple
    destination = [lambda rambda: tuple(map(float, r.split("-"))) for r in ranges]

    # Now execute the lambdas to get the final destination list
    intervals = [rambda(ranges) for rambda in destination]

    # Total count
    total_count = cumsum[-1]

    # Median: find the value where the cumulative sum reaches 50% of the total count
    median_target = total_count * 0.5
    percentile_99_target = total_count * 0.99

    # Find the interval for median and 99th percentile
    median_interval = None
    percentile_99_interval = None

    for i in range(1, len(cumsum)):
        if cumsum[i] >= median_target and median_interval is None:
            median_interval = intervals[i]
        if cumsum[i] >= percentile_99_target and percentile_99_target is None:
            percentile_99_target = intervals[i]

    return median_interval, percentile_99_target

def draw_ecdf_plot(
    ax,
    lims,
    data,
    flowgroup,
    label,
    linestyle,
):
    x_axis = [
        float(item.strip("us").split("-")[1]) - 23.957 for item in data.columns.values
    ]

    x = data.sum().cumsum()
    per50, per99 = get_median_tail(x.index, x.values)
    print("50%=", per50, "99%=", per99)
    max_val = x[-1]

    # (x/max_val).plot(label=grp_index[0],ax=ax)
    if label != 1:
        ax.step(x_axis, (x / max_val) * 100, label=label, linestyle=linestyle, where="post")
    # ax.scatter(x_axis, (x / max_val) * 100, label=label, linestyle=linestyle)
    # ax.step(x, y * 100, label=label, linestyle=linestyle, where='post')

    # set locators
    ax.xaxis.set_major_locator(ticker.AutoLocator())
    ax.xaxis.set_minor_locator(ticker.AutoMinorLocator())
    ax.yaxis.set_major_locator(ticker.AutoLocator())
    ax.yaxis.set_minor_locator(ticker.AutoMinorLocator())

   # ax.set_xlim(lims)
   # ax.set_ylim([0, 100])

    # ax1.legend(loc="upper left", bbox_to_anchor=(1, 0.9), title="Level")
    fig.subplots_adjust(hspace=0.8, wspace=0.4)

    sns.despine()


def draw_ecdf_plots(
    axes,
    data,
    flowgroup,
    lims,
    save,
    directory,
    filename,
    legend_label,
    linestyle="solid",
    colors=plt.rcParams["axes.prop_cycle"].by_key()["color"],
):
    color_iterator = 0
    extended = False

    for i in range(0, len(data)):
        grp_index = list(data.keys())[i]

        if grp_index[0] != 0:
            continue

        df = data[grp_index]
        df = get_only_bins_per_flowgroup(
            df,
            flowgroup["column"],
            flowgroup["name"],
            flowgroup["negative_match"] if "negative_match" in flowgroup else "",
        )

        x = df.sum().cumsum()
        max_val = x[-1]

        ax = None

        line = None
        if type(axes) == np.ndarray:
            if grp_index[-1] == 512:
                draw_ecdf_plot(axes[0], lims, df, flowgroup, legend_label, linestyle)
            if grp_index[-1] == 1518:
                draw_ecdf_plot(axes[1], lims, df, flowgroup, legend_label, linestyle)
        else:
            draw_ecdf_plot(axes, lims, df, flowgroup, legend_label, linestyle)

    # set locators
    #try:
    #    for i in axes:
    #        i.xaxis.set_major_locator(ticker.AutoLocator())
    #        i.xaxis.set_minor_locator(ticker.AutoMinorLocator())
    #        i.yaxis.set_major_locator(ticker.AutoLocator())
    #        i.yaxis.set_minor_locator(ticker.AutoMinorLocator())
    #        i.set(xlabel="Latency (μs)", ylabel="Binned-ECDF (%)")

    #        i.set_xlim(lims)
    #        i.set_ylim([0, 100])
    #except TypeError:
    #    axes.xaxis.set_major_locator(ticker.AutoLocator())
    #    axes.xaxis.set_minor_locator(ticker.AutoMinorLocator())
    #    axes.yaxis.set_major_locator(ticker.AutoLocator())
    #    axes.yaxis.set_minor_locator(ticker.AutoMinorLocator())
    #    axes.set(xlabel="Latency (μs)", ylabel="Binned-ECDF (%)")

    #    axes.set_xlim(lims)
    #    axes.set_ylim([0, 100])

    # ax1[1].legend(loc="upper left", bbox_to_anchor=(1, 0.9), title="Level")
    fig.subplots_adjust(hspace=0.8, wspace=0.4)

    # ax1[0].set_title("Background Traffic:\nPacket Size 512 Byte")
    # ax1[1].set_title("Background Traffic:\nPacket Size 1518 Byte")

    sns.despine()

    if save:
        if not os.path.exists(directory):
            os.makedirs(directory)
        fig.savefig(directory + filename, bbox_inches="tight")

# %#config IPCompleter.greedy=True
# %#matplotlib notebook
# %#matplotlib inline
plt.rcParams["figure.figsize"] = [4, 4]

POINT_PLOT_DODGE = 0.15
sns.set(font_scale=1.25, style="ticks")
FIGSIZE = [6, 6]
plt.style.use("tableau-colorblind10")
# PALETTE = sns.cubehelix_palette(as_cmap\=False, n_colors=3, reverse=False, light=0.7)
print("hot stuff")

# DIR = f"/home/rubinhus/code/datasets/software_hqos_measurements/software_hqos_30x/"
DIR = f"/home/rubinhus/code/datasets/saturn/hybridhqos_30x/"
FILENAME = "Latency Bins"
# EXPERIMENT = "e1_1_port_congestion_27.5gbps_hybrid_30x"
# EXPERIMENT = "Nusers_27.5Gbps_detail"
EXPERIMENT = "profile1_sw"
directory = './' + "output_files/"
filename = f"{EXPERIMENT}_ecdf.pdf"

fig, ax1 = plt.subplots(nrows=1, ncols=1, figsize=[2,2])

csv_files = collect_csv_files(DIR + EXPERIMENT)
merged_df_sw = parse_and_merge_csv(csv_files)
# merged_df.to_csv('/home/rubinhus/code/hqos_batch.csv')

maximums_nusers = {
    (0,'profile1_sw'): 1300,
    (1,'profile1_sw'): 1500,
}
groups_sw = group_and_clean(merged_df_sw, maximums_nusers, ["IPv4 :Raw priority", 'Experiment'])

EXPERIMENT = "profile1_hybrid"
directory = './' + "output_files/"
filename = f"{EXPERIMENT}_ecdf.pdf"

csv_files = collect_csv_files(DIR + EXPERIMENT)
merged_df_hybrid = parse_and_merge_csv(csv_files)
# merged_df.to_csv('/home/rubinhus/code/hqos_batch.csv')
maximums_nusers = {
    (0,'profile1_hybrid'): 100,
    (1,'profile1_hybrid'): 1500,
}
groups_hw = group_and_clean(merged_df_hybrid, maximums_nusers, ["IPv4 :Raw priority", 'Experiment'])


draw_ecdf_plots(
    ax1,
    groups_sw,
    {"column": "IPv4 :Raw priority", "name": 0x0},
    #[0, 2000],
    [0, 1500],
    False,
    directory,
    filename,
    'Software',
)

mins = (merged_df_sw[merged_df_sw["IPv4 :Raw priority"] == 0]['Cut-Through Min Latency (ns)'].min())/10**3-23.957
avg = (merged_df_sw[merged_df_sw["IPv4 :Raw priority"] == 0]['Cut-Through Avg Latency (ns)'].mean())/10**3-23.957
std = (merged_df_sw[merged_df_sw["IPv4 :Raw priority"] == 0]['Cut-Through Avg Latency (ns)'].std())/10**3
maxs = (merged_df_sw[merged_df_sw["IPv4 :Raw priority"] == 0]['Cut-Through Max Latency (ns)'].max())/10**3-23.957

print(f"Sw: Min: {mins:.4f}, Avg: {avg:.4f}, Std: {std:.4f} Max: {maxs:.4f}")

draw_ecdf_plots(
    ax1,
    groups_hw,
    {"column": "IPv4 :Raw priority", "name": 0x0},
    #[0, 2000],
    [0, 100],
    False,
    directory,
    filename,
    'Hybrid',
)

mins = (merged_df_hybrid[merged_df_hybrid["IPv4 :Raw priority"] == 0]['Cut-Through Min Latency (ns)'].min())/10**3-23.957
avg = (merged_df_hybrid[merged_df_hybrid["IPv4 :Raw priority"] == 0]['Cut-Through Avg Latency (ns)'].mean())/10**3-23.957
std = (merged_df_hybrid[merged_df_hybrid["IPv4 :Raw priority"] == 0]['Cut-Through Avg Latency (ns)'].mean())/10**3
maxs = (merged_df_hybrid[merged_df_hybrid["IPv4 :Raw priority"] == 0]['Cut-Through Max Latency (ns)'].max())/10**3-23.957

print(f"Hybrid: Min: {mins:.4f}, Avg: {avg:.4f}, Std: {std:.4f} Max: {maxs:.4f}")

ax1.set_xscale('log')

ax1.set_ylim(-0.2,100)
ax1.set_xlim(0,1500)

# ax1.set_title("Latency distribution of\nhigh priority traffic", pad=20)
ax1.set(xlabel="Latency (μs)", ylabel="Binned-ECDF (%)")

# fig.subplots_adjust(hspace=0.8, wspace=0.6)

ax1.legend(
    title="HQoS",
    #loc="upper left",
    bbox_to_anchor=(1, 1),
    prop={'size': 8}
)
# fig.savefig(directory + '90%' + filename, bbox_inches="tight")
fig.savefig('./' + filename, bbox_inches="tight")

fig, ax2 = plt.subplots(nrows=1, ncols=1, figsize=[2,2])

print('Software Overall Tx data rate:',  merged_df_sw.groupby('IPv4 :Raw priority')['Tx Rate (bps)'].mean()*8/10**9)
print('Hybrid Overall Tx data rate:', merged_df_hybrid.groupby('IPv4 :Raw priority')['Tx Rate (bps)'].mean()*8/10**9)


print('Software Overall Rx data rate: ', merged_df_sw.groupby('IPv4 :Raw priority')['Rx Rate (bps)'].mean()*8/10**9)
print('Hybrid Overall Rx data rate:', merged_df_hybrid.groupby('IPv4 :Raw priority')['Rx Rate (bps)'].mean()*8/10**9)

print('Software std Rx data rate: ', merged_df_sw.groupby('IPv4 :Raw priority')['Rx Rate (bps)'].mean()*8/10**9)
print('Hybrid std Rx data rate:', merged_df_hybrid.groupby('IPv4 :Raw priority')['Rx Rate (bps)'].mean()*8/10**9)


print('Software Overall Loss%:', merged_df_sw.groupby('IPv4 :Raw priority')['Loss %'].mean())
print('Hybrid Overall Loss%: ', merged_df_hybrid.groupby('IPv4 :Raw priority')['Loss %'].mean())
