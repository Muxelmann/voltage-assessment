# Voltage Assessment

[![Build Status](https://travis-ci.org/Muxelmann/voltage-assessment.svg?branch=master)](https://travis-ci.org/Muxelmann/voltage-assessment)

## Overview

The project uses OpenDSS to run multiple power flow simulations of a network and matches power and voltages at specific nodes. With those constraints, all endpoint voltages can be obtained and a voltage probability distribution can be derived. Using mutual information, this link will be formulated mathematically and (hopefully) published.

Some results have been generated already..

### Power matching

Over a certain number of iterations, the random load shapes are adjusted to reduce the power error to the closest Watt.

![Power Error](https://github.com/Muxelmann/voltage-assessment/blob/master/README/power-error.jpg?raw=true)

### Voltage matching

*Still to come...*

### Probability distributions

*Still to come...*

### Mutual information

*Still to come...*
 
## Paper
 
A paper has been added to the repo and is (currently) titled as follows:

![Paper Title](https://github.com/Muxelmann/voltage-assessment/blob/master/README/paper.png?raw=true)

It is encrypted in `paper.crypto`, so nobody can steals it ;)

## Submodule

[OpenDSSDirect.py](https://github.com/NREL/OpenDSSDirect.py) by [Dheepak Krishnamurthy](https://github.com/kdheepak)
