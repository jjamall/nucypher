from cryptography.hazmat.primitives import hashes
from constant_sorrow.constants import KFRAG_LENGTH, CFRAG_LENGTH_WITHOUT_PROOF, CAPSULE_LENGTH, PUBLIC_KEY_LENGTH

BLAKE2B = hashes.BLAKE2b(64)

BLAKE2B_DIGEST_LENGTH = 64
KECCAK_DIGEST_LENGTH = 32

# These lengths are specific to secp256k1
CAPSULE_LENGTH(98)
PUBLIC_KEY_LENGTH(33)
