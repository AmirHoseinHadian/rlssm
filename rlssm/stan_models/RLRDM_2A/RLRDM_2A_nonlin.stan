functions {
     real race_pdf(real t, real b, real v){
          real pdf;
          pdf = b/sqrt(2 * pi() * pow(t, 3)) * exp(-pow(v*t-b, 2) / (2*t));
          return pdf;
     }

     real race_cdf(real t, real b, real v){
          real cdf;
          cdf = Phi((v*t-b)/sqrt(t)) + exp(2*v*b) * Phi(-(v*t+b)/sqrt(t));
          return cdf;
     }

     real race_lpdf(matrix RT, vector  ndt, vector b, vector drift_cor, vector drift_inc){

          real t;
          vector[rows(RT)] prob;
          real cdf;
          real pdf;
          real out;

          for (i in 1:rows(RT)){
               t = RT[i,1] - ndt[i];
               if(t > 0){
                  if(RT[i,2] == 1){
                    pdf = race_pdf(t, b[i], drift_cor[i]);
                    cdf = 1 - race_cdf(t| b[i], drift_inc[i]);
                  }
                  else{
                    pdf = race_pdf(t, b[i], drift_inc[i]);
                    cdf = 1 - race_cdf(t| b[i], drift_cor[i]);
                  }
                  prob[i] = pdf*cdf;

                if(prob[i] < 1e-10){
                    prob[i] = 1e-10;
                }
               }
               else{
                    prob[i] = 1e-10;
               }
          }
          out = sum(log(prob));
          return out;
     }
}

data{
  int<lower=1> N;               // number of data items
  int<lower=1> K;               // number of options
  real initial_value;
  array[N] int<lower=1> block_label;          // block label
  array[N] int<lower=1> trial_block;          // trial within block

  vector[N] f_cor;                // feedback correct option
  vector[N] f_inc;                // feedback incorrect option


  array[N] int<lower=1, upper=K> cor_option;      // correct option
  array[N] int<lower=1, upper=K> inc_option;      // incorrect option
  array[N] int<lower=1, upper=2> accuracy;        // accuracy (1->cor, 2->inc)
  array[N] int<lower=0, upper=1> feedback_type;   // feedback_type = 0 -> full feedback, feedback_type = 1 -> partial feedback

  array[N] real<lower=0> rt;              // reaction time

  vector[2] alpha_priors;             // mean and sd of the prior for alpha
  vector[2] ndt_priors;               // mean and sd of the prior for non-decision time
  vector[2] threshold_priors;         // mean and sd of the prior for threshold
  vector[2] slop_priors;
  vector[2] drift_asym_priors;      // mean and sd of the prior for asymtot modulation
  vector[2] drift_scaling_priors;     // mean and sd of the prior for scaling
  
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
  real alpha;     // learning rate
  real ndt;       // non-decision time
  real threshold;       // threshold
  real slop;
  real drift_asym;
  real drift_scaling;    // scaling
}

transformed parameters {
  vector<lower=0> [N] ndt_t;            // trial-by-trial ndt
  vector<lower=0> [N] threshold_t;        // trial-by-trial threshold
  vector<lower=0> [N] drift_cor_t;        // trial-by-trial drift rate for predictions
  vector<lower=0> [N] drift_inc_t;        // trial-by-trial drift rate for predictions

  real PE_cor;      // prediction error correct option
  real PE_inc;      // prediction error incorrect option
  vector[K] Q;

  real Q_mean;
  real Q_min;
  array[N] real Q_mean_pres;              // mean Q presented options

  real<lower=0, upper=1> transf_alpha;
  real<lower=0> transf_ndt;
  real<lower=0> transf_threshold;
  real<lower=0> transf_slop;
  real<lower=0> transf_drift_asym;
  real<lower=0> transf_drift_scaling;

  transf_alpha = Phi(alpha);
  transf_ndt = log(1 + exp(ndt));
  transf_threshold = log(1 + exp(threshold));
  transf_slop = log(1 + exp(slop));
  transf_drift_asym = log(1 + exp(drift_asym));
  transf_drift_scaling = log(1 + exp(drift_scaling));

  for (n in 1:N){
    if (trial_block[n] == 1){
      if (block_label[n] == 1){
        Q = Q0;
      } else{
        Q_mean = mean(Q);
        Q = rep_vector(Q_mean, K);
      }
    }
    Q_min = min(Q);
    Q_mean_pres[n] = (Q[cor_option[n]] + Q[inc_option[n]])/2;
    PE_cor = f_cor[n] - Q[cor_option[n]];
    PE_inc = f_inc[n] - Q[inc_option[n]];

    drift_cor_t[n] = (transf_drift_scaling + 0.1*transf_drift_asym*(Q_mean_pres[n] - Q_min)) / (1+exp(transf_slop*(Q_mean_pres[n] - Q[cor_option[n]])));
    drift_inc_t[n] = (transf_drift_scaling + 0.1*transf_drift_asym*(Q_mean_pres[n] - Q_min)) / (1+exp(transf_slop*(Q_mean_pres[n] - Q[inc_option[n]])));

    ndt_t[n] = transf_ndt;
    threshold_t[n] = transf_threshold;
    

    if (feedback_type[n] == 1){
      if(accuracy[n] == 1){
        Q[cor_option[n]] = Q[cor_option[n]] + transf_alpha*PE_cor;
      }
      else{
        Q[inc_option[n]] = Q[inc_option[n]] + transf_alpha*PE_inc;
      }
    }
    else{
      Q[cor_option[n]] = Q[cor_option[n]] + transf_alpha*PE_cor;
      Q[inc_option[n]] = Q[inc_option[n]] + transf_alpha*PE_inc;
    }

  }

}

model {
  alpha ~ normal(alpha_priors[1], alpha_priors[2]);
  ndt ~  normal(ndt_priors[1], ndt_priors[2]);
  threshold ~ normal(threshold_priors[1], threshold_priors[2]);
  slop ~ normal(slop_priors[1], slop_priors[2]);
  drift_asym ~ normal(drift_asym_priors[1], drift_asym_priors[2]);
  drift_scaling ~ normal(drift_scaling_priors[1], drift_scaling_priors[2]);

  RT ~ race(ndt_t, threshold_t, drift_cor_t, drift_inc_t);
}

generated quantities {
  vector[N] log_lik;
  {
  for (n in 1:N){
    log_lik[n] = race_lpdf(block(RT, n, 1, 1, 2)| segment(ndt_t, n, 1), segment(threshold_t, n, 1), segment(drift_cor_t, n, 1), segment(drift_inc_t, n, 1));
  }
  }
}
