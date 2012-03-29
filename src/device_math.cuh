#ifndef DEVICE_MATH_H
#define DEVICE_MATH_H

#include "slamtypes.h"
#include <float.h>

/// convolution of two 1D vectors
__host__ std::vector<REAL>
conv(std::vector<REAL> a, std::vector<REAL> b)
{
    int m = a.size() ;
    int n = b.size() ;
    int len = m + n - 1 ;
    std::vector<REAL> c(len) ;
    std::fill( c.begin(),c.end(),0) ;
    for ( int k = 0 ; k < len ; k++ )
    {
        int start_idx = max(0,k-n+1) ;
        int stop_idx = min(k,m-1) ;
        for (int j = start_idx ; j <= stop_idx ; j++ )
        {
            c[k] += a[j]*b[k-j] ;
        }
    }
    return c ;
}

/// wrap an angular value to the range [-pi,pi]
__host__ __device__ REAL
wrapAngle(REAL a)
{
    REAL remainder = fmod(a, REAL(2*M_PI)) ;
    if ( remainder > M_PI )
        remainder -= 2*M_PI ;
    else if ( remainder < -M_PI )
        remainder += 2*M_PI ;
    return remainder ;
}

/// return the closest symmetric positve definite matrix for 2x2 input
__device__ void
makePositiveDefinite( REAL A[4] )
{
    // eigenvalues:
    REAL detA = A[0]*A[3] + A[1]*A[2] ;
    // check if already positive definite
    if ( detA > 0 && A[0] > 0 )
    {
        A[1] = (A[1] + A[2])/2 ;
        A[2] = A[1] ;
        return ;
    }
    REAL trA = A[0] + A[3] ;
    REAL trA2 = trA*trA ;
    REAL eval1 = 0.5*trA + 0.5*sqrt( trA2 - 4*detA ) ;
    REAL eval2 = 0.5*trA - 0.5*sqrt( trA2 - 4*detA ) ;

    // eigenvectors:
    REAL Q[4] ;
    if ( fabs(A[1]) > 0 )
    {
        Q[0] = eval1 - A[3] ;
        Q[1] = A[1] ;
        Q[2] = eval2 - A[3] ;
        Q[3] = A[1] ;
    }
    else if ( fabs(A[2]) > 0 )
    {
        Q[0] = A[2] ;
        Q[1] = eval1 - A[0] ;
        Q[2] = A[2] ;
        Q[3] = eval2 - A[0] ;
    }
    else
    {
        Q[0] = 1 ;
        Q[1] = 0 ;
        Q[2] = 0 ;
        Q[3] = 1 ;
    }

    // make eigenvalues positive
    if ( eval1 < 0 )
        eval1 = DBL_EPSILON ;
    if ( eval2 < 0 )
        eval2 = DBL_EPSILON ;

    // compute the approximate matrix
    A[0] = Q[0]*Q[0]*eval1 + Q[2]*Q[2]*eval2 ;
    A[1] = Q[0]*eval1*Q[1] + Q[2]*eval2*Q[3] ;
    A[2] = A[1] ;
    A[3] = Q[1]*Q[1]*eval1 + Q[3]*Q[3]*eval2 ;
}

/// compute the Mahalanobis distance between two Gaussians
__device__ REAL
computeMahalDist(Gaussian2D a, Gaussian2D b)
{
    REAL innov[2] ;
    REAL sigma[4] ;
    REAL detSigma ;
    REAL sigmaInv[4] = {1,0,0,1} ;
    innov[0] = a.mean[0] - b.mean[0] ;
    innov[1] = a.mean[1] - b.mean[1] ;
//    sigma[0] = a.cov[0] + b.cov[0] ;
//    sigma[1] = a.cov[1] + b.cov[1] ;
//    sigma[2] = a.cov[2] + b.cov[2] ;
//    sigma[3] = a.cov[3] + b.cov[3] ;
//    sigma[0] = a.cov[0] ;
//    sigma[1] = a.cov[1] ;
//    sigma[2] = a.cov[2] ;
//    sigma[3] = a.cov[3] ;
    sigma[0] = b.cov[0] ;
    sigma[1] = b.cov[1] ;
    sigma[2] = b.cov[2] ;
    sigma[3] = b.cov[3] ;
    detSigma = sigma[0]*sigma[3] - sigma[1]*sigma[2] ;
//	detSigma = a.cov[0]*a.cov[3] - a.cov[1]*a.cov[2] ;
    if (detSigma > FLT_MIN)
    {
//		sigmaInv[0] = a.cov[3]/detSigma ;
//		sigmaInv[1] = -a.cov[1]/detSigma ;
//		sigmaInv[2] = -a.cov[2]/detSigma ;
//		sigmaInv[3] = a.cov[0]/detSigma ;
        sigmaInv[0] = sigma[3]/detSigma ;
        sigmaInv[1] = -sigma[1]/detSigma ;
        sigmaInv[2] = -sigma[2]/detSigma ;
        sigmaInv[3] = sigma[0]/detSigma ;
    }
    return  innov[0]*innov[0]*sigmaInv[0] +
            innov[0]*innov[1]*(sigmaInv[1]+sigmaInv[2]) +
            innov[1]*innov[1]*sigmaInv[3] ;
}

/// Compute the Hellinger distance between two Gaussians
__device__ REAL
computeHellingerDist( Gaussian2D a, Gaussian2D b)
{
    REAL innov[2] ;
    REAL sigma[4] ;
    REAL detSigma ;
    REAL sigmaInv[4] = {1,0,0,1} ;
    REAL dist ;
    innov[0] = a.mean[0] - b.mean[0] ;
    innov[1] = a.mean[1] - b.mean[1] ;
    sigma[0] = a.cov[0] + b.cov[0] ;
    sigma[1] = a.cov[1] + b.cov[1] ;
    sigma[2] = a.cov[2] + b.cov[2] ;
    sigma[3] = a.cov[3] + b.cov[3] ;
    detSigma = sigma[0]*sigma[3] - sigma[1]*sigma[2] ;
    if (detSigma > FLT_MIN)
    {
        sigmaInv[0] = sigma[3]/detSigma ;
        sigmaInv[1] = -sigma[1]/detSigma ;
        sigmaInv[2] = -sigma[2]/detSigma ;
        sigmaInv[3] = sigma[0]/detSigma ;
    }
    REAL epsilon = -0.25*
            (innov[0]*innov[0]*sigmaInv[0] +
             innov[0]*innov[1]*(sigmaInv[1]+sigmaInv[2]) +
             innov[1]*innov[1]*sigmaInv[3]) ;

    // determinant of half the sum of covariances
    detSigma /= 4 ;
    dist = 1/detSigma ;

    // product of covariances
    sigma[0] = a.cov[0]*b.cov[0] + a.cov[2]*b.cov[1] ;
    sigma[1] = a.cov[1]*b.cov[0] + a.cov[3]*b.cov[1] ;
    sigma[2] = a.cov[0]*b.cov[2] + a.cov[2]*b.cov[3] ;
    sigma[3] = a.cov[1]*b.cov[2] + a.cov[3]*b.cov[3] ;
    detSigma = sigma[0]*sigma[3] - sigma[1]*sigma[2] ;
    dist *= sqrt(detSigma) ;
    dist = 1 - sqrt(dist)*exp(epsilon) ;
    return dist ;
}

/// a nan-safe logarithm
__device__ __host__
REAL safeLog( REAL x )
{
    if ( x <= 0 )
        return LOG0 ;
    else
        return log(x) ;
}

__device__ void
cholesky( REAL*A, REAL* L, int size)
{
    int i = size ;
    int n_elements = 0 ;
    while(i > 0)
    {
        n_elements += i ;
        i-- ;
    }

    int diag_idx = 0 ;
    int diag_inc = size ;
    L[0] = sqrt(A[0]) ;
    for ( i = 0 ; i < n_elements ; i++ )
    {
        if (i==diag_idx)
        {
            L[i] = A[i] ;
            diag_idx += diag_inc ;
            diag_inc-- ;
        }
    }
}

/// determinant of a 4x4 matrix
__device__ REAL
det4(REAL *A)
{
    REAL det=0;
    det+=A[0]*((A[5]*A[10]*A[15]+A[9]*A[14]*A[7]+A[13]*A[6]*A[11])-(A[5]*A[14]*A[11]-A[9]*A[6]*A[15]-A[13]*A[10]*A[7]));
    det+=A[4]*((A[1]*A[14]*A[11]+A[9]*A[2]*A[15]+A[13]*A[10]*A[3])-(A[1]*A[10]*A[15]-A[9]*A[14]*A[3]-A[13]*A[2]*A[11]));
    det+=A[8]*((A[1]*A[6]*A[15]+A[5]*A[14]*A[3]+A[13]*A[2]*A[7])-(A[1]*A[14]*A[7]-A[5]*A[2]*A[15]-A[13]*A[6]*A[3]));
    det+=A[12]*((A[1]*A[10]*A[7]+A[5]*A[2]*A[12]+A[9]*A[10]*A[3])-(A[1]*A[10]*A[12]-A[5]*A[10]*A[3]-A[9]*A[2]*A[7]));
    return det ;
}

/// invert a 4x4 matrix
__device__ void
invert_matrix4( REAL *A, REAL *A_inv)
{
    double det=det4(A);
    A_inv[0]=A[5]*A[10]*A[15]+A[9]*A[14]*A[7]+A[13]*A[6]*A[11]-A[5]*A[14]*A[11]-A[9]*A[6]*A[15]-A[13]*A[10]*A[7];
    A_inv[4]=A[4]*A[14]*A[11]+A[8]*A[6]*A[15]+A[12]*A[10]*A[7]-A[4]*A[10]*A[15]-A[8]*A[14]*A[7]-A[12]*A[6]*A[11];
    A_inv[8]=A[4]*A[9]*A[15]+A[8]*A[13]*A[7]+A[12]*A[5]*A[11]-A[4]*A[13]*A[11]-A[8]*A[5]*A[15]-A[12]*A[9]*A[7];
    A_inv[12]=A[4]*A[13]*A[10]+A[8]*A[5]*A[14]+A[12]*A[9]*A[6]-A[4]*A[9]*A[14]-A[8]*A[13]*A[6]-A[12]*A[5]*A[10];
    A_inv[1]=A[1]*A[14]*A[11]+A[9]*A[2]*A[15]+A[13]*A[10]*A[3]-A[1]*A[10]*A[15]-A[9]*A[14]*A[3]-A[13]*A[2]*A[11];
    A_inv[5]=A[0]*A[10]*A[15]+A[8]*A[14]*A[3]+A[12]*A[2]*A[11]-A[0]*A[14]*A[11]-A[8]*A[2]*A[15]-A[12]*A[10]*A[3];
    A_inv[9]=A[0]*A[13]*A[11]+A[8]*A[1]*A[15]+A[12]*A[9]*A[3]-A[0]*A[9]*A[15]-A[8]*A[13]*A[3]-A[12]*A[1]*A[11];
    A_inv[13]=A[0]*A[9]*A[14]+A[8]*A[13]*A[2]+A[12]*A[1]*A[10]-A[0]*A[13]*A[10]-A[8]*A[1]*A[14]-A[12]*A[9]*A[2];
    A_inv[2]=A[1]*A[6]*A[15]+A[5]*A[14]*A[3]+A[13]*A[2]*A[7]-A[1]*A[14]*A[7]-A[5]*A[2]*A[15]-A[13]*A[6]*A[3];
    A_inv[6]=A[0]*A[14]*A[7]+A[4]*A[2]*A[15]+A[12]*A[6]*A[3]-A[0]*A[6]*A[15]-A[4]*A[14]*A[3]-A[12]*A[2]*A[7];
    A_inv[10]=A[0]*A[5]*A[15]+A[4]*A[13]*A[3]+A[12]*A[1]*A[7]-A[0]*A[13]*A[7]-A[4]*A[1]*A[15]-A[12]*A[5]*A[3];
    A_inv[14]=A[0]*A[13]*A[6]+A[4]*A[1]*A[14]+A[12]*A[5]*A[2]-A[0]*A[5]*A[14]-A[4]*A[13]*A[2]-A[12]*A[1]*A[6];
    A_inv[3]=A[1]*A[10]*A[7]+A[5]*A[2]*A[11]+A[9]*A[6]*A[3]-A[1]*A[6]*A[11]-A[5]*A[10]*A[3]-A[9]*A[2]*A[7];
    A_inv[7]=A[0]*A[6]*A[11]+A[4]*A[10]*A[3]+A[8]*A[2]*A[7]-A[0]*A[10]*A[7]-A[4]*A[2]*A[11]-A[8]*A[6]*A[3];
    A_inv[11]=A[0]*A[9]*A[7]+A[4]*A[1]*A[11]+A[8]*A[5]*A[3]-A[0]*A[5]*A[11]-A[4]*A[9]*A[3]-A[8]*A[1]*A[7];
    A_inv[15]=A[0]*A[5]*A[10]+A[4]*A[9]*A[2]+A[8]*A[1]*A[6]-A[0]*A[9]*A[6]-A[4]*A[1]*A[10]-A[8]*A[5]*A[2];
    for (int i = 0 ; i<16 ; i++)
        A_inv[i] /= det ;
}

/// device function for summations by parallel reduction in shared memory
/*!
  * Implementation based on NVIDIA whitepaper found at:
  * http://developer.download.nvidia.com/compute/cuda/1_1/Website/projects/reduction/doc/reduction.pdf
  *
  * Result is stored in sdata[0]
  \param sdata pointer to shared memory array
  \param mySum summand loaded by the thread
  \param tid thread index
  */
__device__ void
sumByReduction( volatile REAL* sdata, REAL mySum, const unsigned int tid )
{
    sdata[tid] = mySum;
    __syncthreads();

    // do reduction in shared mem
    if (tid < 128) { sdata[tid] = mySum = mySum + sdata[tid + 128]; } __syncthreads();
    if (tid <  64) { sdata[tid] = mySum = mySum + sdata[tid +  64]; } __syncthreads();

    if (tid < 32)
    {
        sdata[tid] = mySum = mySum + sdata[tid + 32];
        sdata[tid] = mySum = mySum + sdata[tid + 16];
        sdata[tid] = mySum = mySum + sdata[tid +  8];
        sdata[tid] = mySum = mySum + sdata[tid +  4];
        sdata[tid] = mySum = mySum + sdata[tid +  2];
        sdata[tid] = mySum = mySum + sdata[tid +  1];
    }
    __syncthreads() ;
}

/// device function for products by parallel reduction in shared memory
/*!
  * Implementation based on NVIDIA whitepaper found at:
  * http://developer.download.nvidia.com/compute/cuda/1_1/Website/projects/reduction/doc/reduction.pdf
  *
  * Result is stored in sdata[0]
  \param sdata pointer to shared memory array
  \param my_factor factor loaded by the thread
  \param tid thread index
  */
__device__ void
productByReduction( volatile REAL* sdata, REAL my_factor, const unsigned int tid )
{
    sdata[tid] = my_factor;
    __syncthreads();

    // do reduction in shared mem
    if (tid < 128) { sdata[tid] = my_factor = my_factor * sdata[tid + 128]; } __syncthreads();
    if (tid <  64) { sdata[tid] = my_factor = my_factor * sdata[tid +  64]; } __syncthreads();

    if (tid < 32)
    {
        sdata[tid] = my_factor = my_factor * sdata[tid + 32];
        sdata[tid] = my_factor = my_factor * sdata[tid + 16];
        sdata[tid] = my_factor = my_factor * sdata[tid +  8];
        sdata[tid] = my_factor = my_factor * sdata[tid +  4];
        sdata[tid] = my_factor = my_factor * sdata[tid +  2];
        sdata[tid] = my_factor = my_factor * sdata[tid +  1];
    }
    __syncthreads() ;
}

/// device function for finding max value by parallel reduction in shared memory
/*!
  * Implementation based on NVIDIA whitepaper found at:
  * http://developer.download.nvidia.com/compute/cuda/1_1/Website/projects/reduction/doc/reduction.pdf
  *
  * Result is stored in sdata[0]. Other values in the array are garbage.
  \param sdata pointer to shared memory array
  \param val value loaded by the thread
  \param tid thread index
  */
__device__ void
maxByReduction( volatile REAL* sdata, REAL val, const unsigned int tid )
{
    sdata[tid] = val ;
    __syncthreads();

    // do reduction in shared mem
    if (tid < 128) { sdata[tid] = val = fmax(sdata[tid+128],val) ; } __syncthreads();
    if (tid <  64) { sdata[tid] = val = fmax(sdata[tid+64],val) ; } __syncthreads();

    if (tid < 32)
    {
        sdata[tid] = val = fmax(sdata[tid+32],val) ;
        sdata[tid] = val = fmax(sdata[tid+16],val) ;
        sdata[tid] = val = fmax(sdata[tid+8],val) ;
        sdata[tid] = val = fmax(sdata[tid+4],val) ;
        sdata[tid] = val = fmax(sdata[tid+2],val) ;
        sdata[tid] = val = fmax(sdata[tid+1],val) ;
    }
    __syncthreads() ;
}

typedef struct
{
    REAL std_accx ;
    REAL std_accy ;
    __device__ __host__ Gaussian4D
    compute_prediction(Gaussian4D state_prior, REAL dt)
    {
        Gaussian4D state_predict ;
        // predicted weight
        state_predict.weight = state_prior.weight ;

        // predicted mean
        state_predict.mean[0] = state_prior.mean[0] + dt*state_prior.mean[2] ;
        state_predict.mean[1] = state_prior.mean[1] + dt*state_prior.mean[3] ;
        state_predict.mean[2] = state_prior.mean[2] ;
        state_predict.mean[3] = state_prior.mean[3] ;

        // predicted covariance
        REAL var_x = pow(std_accx,2) ;
        REAL var_y = pow(std_accy,2) ;
        state_predict.cov[0] = state_prior.cov[0] + state_prior.cov[8] * dt
                + dt * (state_prior.cov[2] + state_prior.cov[10] * dt)
                + pow(dt, 0.4e1) *var_x / 0.4e1;
        state_predict.cov[4] = state_prior.cov[4] + state_prior.cov[12] * dt
                + dt * (state_prior.cov[6] + state_prior.cov[14] * dt);
        state_predict.cov[8] = state_prior.cov[8] + state_prior.cov[10] * dt
                + pow(dt, 0.3e1) *var_x / 0.2e1;
        state_predict.cov[12] = state_prior.cov[12] + state_prior.cov[14] * dt;
        state_predict.cov[1] = state_prior.cov[1] + state_prior.cov[9] * dt
                + dt * (state_prior.cov[3] + state_prior.cov[11] * dt);
        state_predict.cov[5] = state_prior.cov[5] + state_prior.cov[13] * dt
                + dt * (state_prior.cov[7] + state_prior.cov[15] * dt)
                + pow(dt, 0.4e1) * var_y / 0.4e1;
        state_predict.cov[9] = state_prior.cov[9] + state_prior.cov[11] * dt;
        state_predict.cov[13] = state_prior.cov[13] + state_prior.cov[15] * dt
                + pow(dt, 0.3e1) * var_y / 0.2e1;
        state_predict.cov[2] = state_prior.cov[2] + state_prior.cov[10] * dt
                + pow(dt, 0.3e1) *var_x / 0.2e1;
        state_predict.cov[6] = state_prior.cov[6] + state_prior.cov[14] * dt;
        state_predict.cov[10] = state_prior.cov[10] +var_x * dt * dt;
        state_predict.cov[14] = state_prior.cov[14];
        state_predict.cov[3] = state_prior.cov[3] + state_prior.cov[11] * dt;
        state_predict.cov[7] = state_prior.cov[7] + state_prior.cov[15] * dt
                + pow(dt, 0.3e1) * var_y / 0.2e1;
        state_predict.cov[11] = state_prior.cov[11];
        state_predict.cov[15] = state_prior.cov[15] + var_y * dt * dt;

        return state_predict ;
    }
} ConstantVelocityMotionModel ;

typedef struct
{
    REAL std_vx ;
    REAL std_vy ;
    __device__ __host__ Gaussian2D
    compute_prediction(Gaussian2D state_prior, REAL dt)
    {
        Gaussian2D state_predict ;
        // predicted weight
        state_predict.weight = state_prior.weight ;

        // predicted mean
        state_predict.mean[0] = state_prior.mean[0] ;
        state_predict.mean[1] = state_prior.mean[1] ;

        // predicted covariance
        state_predict.cov[0] = state_prior.cov[0] + pow(std_vx*dt,2) ;
        state_predict.cov[1] = state_prior.cov[1] ;
        state_predict.cov[2] = state_prior.cov[2] ;
        state_predict.cov[3] = state_prior.cov[3] + pow(std_vy*dt,2) ;

        return state_predict ;
    }
} ConstantPositionMotionModel ;

template<class GaussianType>
__device__ __host__
void copy_gaussians(GaussianType* src, GaussianType* dest)
{
    // determine the size of the covariance matrix
    int len_cov = sizeof(src->cov)/sizeof(REAL) ;
#ifdef __CUDA_ARCH__
    int len_mean = sqrtf(len_cov) ;
#else
    int len_mean = sqrt(len_cov) ;
#endif
    // copy mean and covariance
    for (int i = 0 ; i < len_cov ; i++ )
    {
        if ( i < len_mean )
            dest->mean[i] = src->mean[i] ;
        dest->cov[i] = src->cov[i] ;
    }

    // copy weight
    dest->weight = src->weight ;
}


#endif // DEVICE_MATH_H
