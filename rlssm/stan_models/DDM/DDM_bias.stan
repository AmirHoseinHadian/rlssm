data {
	int<lower=1> N;									// number of data items

	array[N] int<lower=-1,upper=1> accuracy;			// accuracy (-1, 1)
	array[N] int<lower=0,upper=1> accuracy_flipped;		// flipped accuracy (1, 0)
	array[N] real<lower=0> rt;							// rt

	vector[2] drift_priors;							// mean and sd of the prior
	vector[2] threshold_priors;						// mean and sd of the prior
	vector[2] ndt_priors;							// mean and sd of the prior
	vector[2] rel_sp_priors;						// mean and sd of the prior
}
parameters {
	real drift;
	real threshold;
	real ndt;
	real rel_sp;
}
transformed parameters {
	array[N] real drift_ll;								// trial-by-trial drift rate for likelihood (incorporates accuracy)
	array[N] real drift_t;								// trial-by-trial drift rate for predictions
	array[N] real<lower=0> threshold_t;					// trial-by-trial threshold   
	array[N] real<lower=0> ndt_t;						// trial-by-trial ndt
	array[N] real<lower=0, upper=1> rel_sp_ll;			// trial-by-trial relative starting point for likelihood (incorporates accuracy)
	array[N] real<lower=0, upper=1> rel_sp_t;			// trial-by-trial relative starting point

	real transf_drift;
	real transf_threshold;
	real transf_ndt;
	real transf_rel_sp;

	transf_drift = drift;							// for the output
	transf_threshold = log(1 + exp(threshold));
	transf_ndt = log(1 + exp(ndt));
	transf_rel_sp = Phi(rel_sp);

	for (n in 1:N) {
		drift_t[n] = transf_drift;
		drift_ll[n] = drift_t[n]*accuracy[n];
		threshold_t[n] = transf_threshold;
		ndt_t[n] = transf_ndt;
		rel_sp_t[n] = transf_rel_sp;
		rel_sp_ll[n] = accuracy_flipped[n] + accuracy[n]*rel_sp_t[n];
	}
}
model {
	drift ~ normal(drift_priors[1], drift_priors[2]);
	threshold ~ normal(threshold_priors[1], threshold_priors[2]);
	ndt ~ normal(ndt_priors[1], ndt_priors[2]);
	rel_sp ~ normal(rel_sp_priors[1], rel_sp_priors[2]);

	rt ~ wiener(threshold_t, ndt_t, rel_sp_ll, drift_ll);
}
generated quantities {
	vector[N] log_lik;

	{for (n in 1:N) {
		log_lik[n] = wiener_lpdf(rt[n] | threshold_t[n], ndt_t[n], rel_sp_ll[n], drift_ll[n]);
	}
}
}