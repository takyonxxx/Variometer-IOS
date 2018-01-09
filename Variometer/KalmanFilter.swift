//
//  KalmanFilter.swift
//  Variometer
//
//  Created by Türkay Biliyor on 11.12.2017.
//  Copyright © 2017 Türkay Biliyor. All rights reserved.
//

import Foundation

class KalmanFilter
{
    var var_x_accel_ : Double = 0.0
    var x_abs_ : Double = 0.0
    var x_vel_ : Double = 0.0
    var p_abs_abs_ : Double = 0.0
    var p_abs_vel_ : Double = 0.0
    var p_vel_vel_ : Double = 0.0
    
    func start(x_accel : Double) {
        var_x_accel_ = x_accel
        Reset(x_abs_value: 0.0, x_vel_value: 0.0)
    }
    
    func Reset(x_abs_value: Double, x_vel_value: Double)
    {
        x_abs_ = x_abs_value;
        x_vel_ = x_vel_value;
        p_abs_abs_ = 1e6;
        p_abs_vel_ = 0;
        p_vel_vel_ = var_x_accel_;
    }
    
    func Update(z_abs : Double, var_z_abs : Double, dt: Double)
    {
        let F1 : Double = 1.0
        
        // Validity checks. TODO: more?
        assert(dt > 0);
        
        // Note: math is not optimized by hand. Let the compiler sort it out.
        // Predict step.
        // Update state estimate.
        x_abs_ += x_vel_ * dt;
        // Update state covariance. The last term mixes in acceleration noise.
        let dt2 = pow(dt,dt);
        let dt3 = dt * dt2;
        let dt4 = pow(dt2,dt2);
        p_abs_abs_ += 2 * dt * p_abs_vel_ + dt2 * p_vel_vel_ + var_x_accel_ * dt4 / 4;
        p_abs_vel_ += dt * p_vel_vel_ + var_x_accel_ * dt3 / 2;
        p_vel_vel_ += var_x_accel_ * dt2;
        
        // Update step.
        let y = z_abs - x_abs_;  // Innovation.
        let s_inv = F1 / (p_abs_abs_ + var_z_abs);  // Innovation precision.
        let k_abs = p_abs_abs_*s_inv;  // Kalman gain
        let k_vel = p_abs_vel_*s_inv;
        // Update state estimate.
        x_abs_ += k_abs * y;
        x_vel_ += k_vel * y;
        // Update state covariance.
        p_vel_vel_ -= p_abs_vel_*k_vel;
        p_abs_vel_ -= p_abs_vel_*k_abs;
        p_abs_abs_ -= p_abs_abs_*k_abs;
        
    }
    
    func GetXAbs() -> Double { return x_abs_; }
    func GetXVel() -> Double { return x_vel_; }
    func GetCovAbsAbs() -> Double { return p_abs_abs_; }
    func GetCovAbsVel() -> Double { return p_abs_vel_; }
    func GetCovVelVel() -> Double { return p_vel_vel_; }
}
