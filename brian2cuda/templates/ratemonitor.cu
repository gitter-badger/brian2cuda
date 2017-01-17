{% extends 'common_group.cu' %}
{# USES_VARIABLES { rate, t, _spikespace, _clock_t, _clock_dt,
                    _num_source_neurons, _source_start, _source_stop } #}

{% block extra_maincode %}
int current_iteration = {{owner.clock.name}}.timestep[0];
static unsigned int start_offset = current_iteration;
static bool first_run = true;
if(first_run)
{
	int num_iterations = {{owner.clock.name}}.i_end;
	unsigned int size_till_now = dev{{_dynamic_t}}.size();
	dev{{_dynamic_t}}.resize(num_iterations + size_till_now - start_offset);
	dev{{_dynamic_rate}}.resize(num_iterations + size_till_now - start_offset);
	first_run = false;
}
{% endblock %}

{% block kernel_call %}
_run_{{codeobj_name}}_kernel<<<1,1>>>(
	current_iteration - start_offset,
	thrust::raw_pointer_cast(&(dev{{_dynamic_rate}}[0])),
	thrust::raw_pointer_cast(&(dev{{_dynamic_t}}[0])),
	///// HOST_PARAMETERS /////
	%HOST_PARAMETERS%);
{% endblock %}

{% block kernel %}
__global__ void _run_{{codeobj_name}}_kernel(
	int32_t current_iteration,
	double* ratemonitor_rate,
	double* ratemonitor_t,
	///// DEVICE_PARAMETERS /////
	%DEVICE_PARAMETERS%
	)
{
	using namespace brian;

	///// KERNEL_VARIABLES /////
	%KERNEL_VARIABLES%

	unsigned int num_spikes = 0;

	if (_num_spikespace-1 != _num_source_neurons)  // we have a subgroup
	{
		for (unsigned int i=0; i < _num_spikespace; i++)
		{
			const int spiking_neuron = {{_spikespace}}[i];
			if (spiking_neuron != -1)
			{	
				// check if spiking neuron is in this subgroup
				if (_source_start <= spiking_neuron && spiking_neuron < _source_stop)
					num_spikes++;
			}
			else  // end of spiking neurons
			{
				break;
			}
		}
	}
	else  // we don't have a subgroup
	{
	num_spikes = {{_spikespace}}[_num_source_neurons];
	}

	// TODO: we should be able to use {{rate}} and {{t}} here instead of passing these
	//		 additional pointers. But this results in thrust::system_error illegal memory access.
	//       Don't know why... {{rate}} and ratemonitor_rate should be the same...
	ratemonitor_rate[current_iteration] = 1.0*num_spikes/{{_clock_dt}}/_num_source_neurons;
	ratemonitor_t[current_iteration] = {{_clock_t}};
}
{% endblock %}
