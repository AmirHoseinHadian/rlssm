data {
	int<lower=1> N;									// number of data items
	int<lower=1> K;									// number of options
	array[N] int<lower=1> trial_block;				// trial within block
	vector[N] f_cor;								// feedback correct option
	vector[N] f_inc;								// feedback incorrect option
	array[N] int<lower=1, upper=K> cor_option;		// correct option
	array[N] int<lower=1, upper=K> inc_option;		// incorrect option
	array[N] int<lower=1> block_label;				// block label
	array[N] int<lower=-1,upper=1> accuracy;		// accuracy (0, 1)
	array[N] int<lower=0, upper=1> feedback_type; 	// feedback_type = 0 -> full feedback, feedback_type = 1 -> partial feedback
	real initial_value;								// intial value for learning in the first block
	vector[2] alpha_pos_priors;						// mean and sd of the alpha_pos prior
	vector[2] alpha_neg_priors;						// mean and sd of the alpha_neg prior
	vector[2] sensitivity_priors;					// mean and sd of the sensitivity prior
}
transformed data {
	vector[K] Q0;
	Q0 = rep_vector(initial_value, K);
}
parameters {
	real alpha_pos;
	real alpha_neg;
	real sensitivity;
}
transformed parameters {
	array[N] real log_p_t;							// trial-by-trial probability
	vector[K] Q;									// Q state values

	real PE_cor;
	real PE_inc;
	real Q_mean;

	real transf_alpha_pos;
	real transf_alpha_neg;
	real transf_sensitivity;

	transf_alpha_pos = Phi(alpha_pos);
	transf_alpha_neg = Phi(alpha_neg);
	transf_sensitivity = log(1 + exp(sensitivity));

	for (n in 1:N) {
		if (trial_block[n] == 1) {
			if (block_label[n] == 1) {
				Q = Q0;
			} else {
				Q_mean = mean(Q);
				Q = rep_vector(Q_mean, K);
			}
		}
		PE_cor = f_cor[n] - Q[cor_option[n]];
		PE_inc = f_inc[n] - Q[inc_option[n]];

		log_p_t[n] = transf_sensitivity*Q[cor_option[n]] - log(exp(transf_sensitivity*Q[cor_option[n]]) + exp(transf_sensitivity*Q[inc_option[n]]));

		if (feedback_type[n] == 1){
      if(accuracy[n] == 1){
        if (PE_cor >= 0) {
          Q[cor_option[n]] = Q[cor_option[n]] + transf_alpha_pos*PE_cor;
        } else {
          Q[cor_option[n]] = Q[cor_option[n]] + transf_alpha_neg*PE_cor;
        }
      }
      else{
        if (PE_inc >= 0) {
          Q[inc_option[n]] = Q[inc_option[n]] + transf_alpha_pos*PE_inc;
        } else {
          Q[inc_option[n]] = Q[inc_option[n]] + transf_alpha_neg*PE_inc;
        }
      }
    }
    else{
      if (PE_cor >= 0) {
        Q[cor_option[n]] = Q[cor_option[n]] + transf_alpha_pos*PE_cor;
      } else {
        Q[cor_option[n]] = Q[cor_option[n]] + transf_alpha_neg*PE_cor;
      }
      if (PE_inc >= 0) {
        Q[inc_option[n]] = Q[inc_option[n]] + transf_alpha_pos*PE_inc;
      } else {
        Q[inc_option[n]] = Q[inc_option[n]] + transf_alpha_neg*PE_inc;
      }
    }
    
	}
}
model {
	alpha_pos ~ normal(alpha_pos_priors[1], alpha_pos_priors[2]);
	alpha_neg ~ normal(alpha_neg_priors[1], alpha_neg_priors[2]);
	sensitivity ~ normal(sensitivity_priors[1], sensitivity_priors[2]);

	accuracy ~ bernoulli(exp(log_p_t));
}
generated quantities {
	vector[N] log_lik;

	{for (n in 1:N) {
		log_lik[n] = bernoulli_lpmf(accuracy[n] | exp(log_p_t[n]));
	}
	}
}