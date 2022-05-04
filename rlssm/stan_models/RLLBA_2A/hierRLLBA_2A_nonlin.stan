functions{

     real lba_pdf(real t, real b, real A, real v, real s){
          //PDF of the LBA model
          real b_A_tv_ts;
          real b_tv_ts;
          real term_1;
          real term_2;
          real term_3;
          real term_4;
          real pdf;

          b_A_tv_ts = (b - A - t*v)/(t*s);
          b_tv_ts = (b - t*v)/(t*s);
          term_1 = v*Phi(b_A_tv_ts);
          term_2 = s*exp(normal_log(b_A_tv_ts,0,1));
          term_3 = v*Phi(b_tv_ts);
          term_4 = s*exp(normal_log(b_tv_ts,0,1));
          pdf = (1/A)*(-term_1 + term_2 + term_3 - term_4);

          return pdf;
     }

     real lba_cdf(real t, real b, real A, real v, real s){
          //CDF of the LBA model

          real b_A_tv;
          real b_tv;
          real ts;
          real term_1;
          real term_2;
          real term_3;
          real term_4;
          real cdf;

          b_A_tv = b - A - t*v;
          b_tv = b - t*v;
          ts = t*s;
          term_1 = b_A_tv/A * Phi(b_A_tv/ts);
          term_2 = b_tv/A   * Phi(b_tv/ts);
          term_3 = ts/A * exp(normal_log(b_A_tv/ts,0,1));
          term_4 = ts/A * exp(normal_log(b_tv/ts,0,1));
          cdf = 1 + term_1 - term_2 + term_3 - term_4;

          return cdf;

     }

     real lba_lpdf(matrix RT, vector rel_sp, vector threshold, vector drift_cor, vector drift_inc, vector ndt){

          real t;
          real b;
          real cdf;
          real pdf;
          vector[rows(RT)] prob;
          real out;
          real prob_neg;
          real s;
          s = 1;

          for (i in 1:rows(RT)){
               b = threshold[i] + rel_sp[i];
               t = RT[i,1] - ndt[i];
               if(t > 0){
                    cdf = 1;

                    if(RT[i,2] == 1){
                      pdf = lba_pdf(t, b, threshold[i], drift_cor[i], s);
                      cdf = 1-lba_cdf(t, b, threshold[i], drift_inc[i], s);
                    }
                    else{
                      pdf = lba_pdf(t, b, threshold[i], drift_inc[i], s);
                      cdf = 1-lba_cdf(t, b, threshold[i], drift_cor[i], s);
                    }
                    prob_neg = Phi(-drift_cor[i]/s) * Phi(-drift_inc[i]/s);
                    prob[i] = pdf*cdf;
                    prob[i] = prob[i]/(1-prob_neg);
                    if(prob[i] < 1e-10){
                         prob[i] = 1e-10;
                    }

               }else{
                    prob[i] = 1e-10;
               }
          }
          out = sum(log(prob));
          return out;
     }
}

data {
	int<lower=1> N;									// number of data items
  int<lower=1> L;								// number of participants
  int<lower=1> K;               // number of options

  int<lower=1, upper=L> participant[N];			// level (participant)

  real initial_value;

  int<lower=1> block_label[N];					// block label
  int<lower=1> trial_block[N];					// trial within block

  vector[N] f_cor;								// feedback correct option
	vector[N] f_inc;								// feedback incorrect option

  int<lower=1, upper=K> cor_option[N];			// correct option
	int<lower=1, upper=K> inc_option[N];			// incorrect option

	int<lower=1,upper=2> accuracy[N];				// 1-> correct, 2->incorrect
	real<lower=0> rt[N];							// rt

  vector[4] rel_sp_priors;
	vector[4] threshold_priors;
  vector[4] ndt_priors;
  vector[4] utility_priors;
  vector[4] alpha_priors;             // mean and sd of the prior for alpha
	vector[4] drift_scaling_priors;			// mean and sd of the prior for scaling
}

transformed data {
	vector[K] Q0;
  matrix [N, 2] RT;

  Q0 = rep_vector(initial_value, K);

  for (n in 1:N){
    RT[n, 1] = rt[n];
    RT[n, 2] = accuracy[n];
  }
}

parameters {
   real mu_rel_sp;
   real mu_threshold;
   real mu_ndt;
   real mu_utility;
 	 real mu_alpha;            // learning rate
   real mu_drift_scaling;    // scaling

   real<lower=0> sd_rel_sp;
   real<lower=0> sd_threshold;
   real<lower=0> sd_ndt;
   real<lower=0> sd_utility;
 	 real<lower=0> sd_alpha;            // learning rate
   real<lower=0> sd_drift_scaling;    // scaling

   real z_rel_sp[L];
   real z_threshold[L];
   real z_ndt[L];
   real z_utility[L];
 	 real z_alpha[L];            // learning rate
   real z_drift_scaling[L];    // scaling
}

transformed parameters {
  vector<lower=0> [N] rel_sp_t;				    // trial-by-trial
	vector<lower=0> [N] threshold_t;						// trial-by-trial
  vector<lower=0> [N] ndt_t;				 // trial-by-trial ndt
	vector<lower=0> [N] drift_cor_t;				// trial-by-trial drift rate for predictions
	vector<lower=0> [N] drift_inc_t;				// trial-by-trial drift rate for predictions

  real PE_cor;			// prediction error correct option
	real PE_inc;			// prediction error incorrect option
	vector[K] Q;

  real Q_mean;

  real<lower=0> rel_sp_sbj[L];
	real<lower=0> threshold_sbj[L];
  real<lower=0> ndt_sbj[L];
  real<lower=0> utility_sbj[L];
  real<lower=0, upper=1> alpha_sbj[L];
	real<lower=0> drift_scaling_sbj[L];

  real<lower=0> transf_mu_rel_sp;
  real<lower=0> transf_mu_threshold;
  real<lower=0> transf_mu_ndt;
  real<lower=0> transf_mu_utility;
  real<lower=0, upper=1> transf_mu_alpha;
	real<lower=0> transf_mu_drift_scaling;

  transf_mu_rel_sp = log(1 + exp(mu_rel_sp));
	transf_mu_threshold = log(1 + exp(mu_threshold));
	transf_mu_ndt = log(1 + exp(mu_ndt));
  transf_mu_utility = log(1 + exp(mu_utility));
  transf_mu_alpha = Phi(mu_alpha);
	transf_mu_drift_scaling = log(1 + exp(mu_drift_scaling));

  for (l in 1:L) {
    rel_sp_sbj[l] = log(1 + exp(mu_rel_sp + z_rel_sp[l]*sd_rel_sp));
    threshold_sbj[l] = log(1 + exp(mu_threshold + z_threshold[l]*sd_threshold));
    ndt_sbj[l] = log(1 + exp(mu_ndt + z_ndt[l]*sd_ndt));
    utility_sbj[l] = log(1 + exp(mu_utility + z_utility[l] * sd_utility));
		alpha_sbj[l] = Phi(mu_alpha + z_alpha[l]*sd_alpha);
		drift_scaling_sbj[l] = log(1 + exp(mu_drift_scaling + z_drift_scaling[l]*sd_drift_scaling));
	}

	for (n in 1:N) {
    if (trial_block[n] == 1){
			if (block_label[n] == 1){
				Q = Q0;
			} else{
				Q_mean = mean(Q);
				Q = rep_vector(Q_mean, K);
			}
		}

    PE_cor = f_cor[n] - Q[cor_option[n]];
		PE_inc = f_inc[n] - Q[inc_option[n]];

    rel_sp_t[n] = rel_sp_sbj[participant[n]];
		threshold_t[n] = threshold_sbj[participant[n]];
    ndt_t[n] = ndt_sbj[participant[n]];

    if (2*Q[cor_option[n]] - Q[inc_option[n]] > 0){
      drift_cor_t[n] = drift_scaling_sbj[participant[n]]* pow(2*Q[cor_option[n]] - Q[inc_option[n]] + 1, utility_sbj[participant[n]]);
    }else{
      drift_cor_t[n] = drift_scaling_sbj[participant[n]] * pow(exp(2*Q[cor_option[n]] - Q[inc_option[n]]), utility_sbj[participant[n]]);
    }
    if (2*Q[inc_option[n]] - Q[cor_option[n]]>0){
      drift_inc_t[n] = drift_scaling_sbj[participant[n]] * pow(2*Q[inc_option[n]] - Q[cor_option[n]] + 1, utility_sbj[participant[n]]);
    }else{
      drift_inc_t[n] = drift_scaling_sbj[participant[n]] * pow(exp(2*Q[inc_option[n]] - Q[cor_option[n]]), utility_sbj[participant[n]]);
    }

    Q[cor_option[n]] = Q[cor_option[n]] + alpha_sbj[participant[n]]*PE_cor;
		Q[inc_option[n]] = Q[inc_option[n]] + alpha_sbj[participant[n]]*PE_inc;
	}
}

model {
     mu_rel_sp ~ normal(rel_sp_priors[1], rel_sp_priors[2]);
     mu_threshold ~ normal(threshold_priors[1], threshold_priors[2]);
     mu_ndt ~ normal(ndt_priors[1], ndt_priors[2]);
     mu_utility ~ normal(utility_priors[1], utility_priors[2]);
     mu_alpha ~ normal(alpha_priors[1], alpha_priors[2]);
   	 mu_drift_scaling ~ normal(drift_scaling_priors[1], drift_scaling_priors[2]);

     sd_rel_sp ~ normal(rel_sp_priors[3], rel_sp_priors[4]);
     sd_threshold ~ normal(threshold_priors[3], threshold_priors[4]);
     sd_ndt ~ normal(ndt_priors[3], ndt_priors[4]);
     sd_utility ~ normal(utility_priors[3], utility_priors[4]);
     sd_alpha ~ normal(alpha_priors[3], alpha_priors[4]);
   	 sd_drift_scaling ~ normal(drift_scaling_priors[3], drift_scaling_priors[4]);

     z_rel_sp ~ normal(0, 1);
     z_threshold ~ normal(0, 1);
     z_ndt ~ normal(0, 1);
     z_utility ~ normal(0, 1);
     z_alpha ~ normal(0, 1);
   	 z_drift_scaling ~ normal(0, 1);

     RT ~ lba(rel_sp_t, threshold_t, drift_cor_t, drift_inc_t, ndt_t);
}

generated quantities {
    vector[N] log_lik;
  	{
    	for (n in 1:N){
    		log_lik[n] = lba_lpdf(block(RT, n, 1, 1, 2)| segment(rel_sp_t, n, 1), segment(threshold_t, n, 1), segment(drift_cor_t, n, 1), segment(drift_inc_t, n, 1), segment(ndt_t, n, 1));
    	}
  	}
}