#!/usr/bin/env python3
import os
from pathlib import Path
from cryptography import x509
from cryptography.hazmat.primitives import serialization, hashes

CERTS_DIR = os.getenv("CERTS_DIR")

if CERTS_DIR is None:
    raise RuntimeError("CERTS_DIR not set")

def load_cert(filename):
    with open(filename, 'rb') as f:
        if filename.endswith('.der'):
            return x509.load_der_x509_certificate(f.read())
        else:
            return x509.load_pem_x509_certificate(f.read())

def load_private_key(filename):
    with open(filename, 'rb') as f:
        return serialization.load_pem_private_key(f.read(), password=None)

# Load original certificate to extract SCT extension
original_cert = load_cert(os.path.join(CERTS_DIR, 'original.crt'))
basic_cert = load_cert(os.path.join(CERTS_DIR, 'server-raw.crt'))
ca_cert = load_cert(os.path.join(CERTS_DIR, 'ca.crt'))
ca_key = load_private_key(os.path.join(CERTS_DIR, 'ca.key'))
server_key = load_private_key(os.path.join(CERTS_DIR, 'server.key'))

# Try to get SCT extension from original certificate
sct_extension = None
try:
    sct_extension = original_cert.extensions.get_extension_for_oid(
        x509.ObjectIdentifier("1.3.6.1.4.1.11129.2.4.2")  # CT SCT extension OID
    )
    print("Found SCT extension in original certificate")
except x509.ExtensionNotFound:
    print("No SCT extension found in original certificate")

# Build new certificate with all extensions from basic cert plus SCT
builder = x509.CertificateBuilder()
builder = builder.subject_name(basic_cert.subject)
builder = builder.issuer_name(basic_cert.issuer)
builder = builder.public_key(basic_cert.public_key())
builder = builder.serial_number(basic_cert.serial_number)
builder = builder.not_valid_before(basic_cert.not_valid_before)
builder = builder.not_valid_after(basic_cert.not_valid_after)

# Add all existing extensions
for ext in basic_cert.extensions:
    builder = builder.add_extension(ext.value, critical=ext.critical)

# Add SCT extension if found
if sct_extension:
    builder = builder.add_extension(sct_extension.value, critical=sct_extension.critical)

# Sign the certificate
final_cert = builder.sign(ca_key, hashes.SHA384())

# Save the final certificate
with open(os.path.join(CERTS_DIR, 'server.crt'), 'wb') as f:
    f.write(final_cert.public_bytes(serialization.Encoding.PEM))
