package eu.nebulous.service;

import jakarta.enterprise.context.ApplicationScoped;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.bouncycastle.openssl.jcajce.JcaPEMWriter;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.StringWriter;
import java.security.Key;
import java.security.KeyPairGenerator;
import java.security.PublicKey;
import java.security.Security;
import java.security.interfaces.RSAPublicKey;
import java.util.Base64;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

@ApplicationScoped
public class SSHKeyPairGeneratorService {

    private static final Logger logger = Logger.getLogger(SSHKeyPairGeneratorService.class.getName());

    public Map<String, String> createOpenSSL(String publicIp) {
        var openSSLKeyPairHashMap = new HashMap<String, String>();
        try {
            Security.addProvider(new BouncyCastleProvider());

            // Generate the RSA Key Pair
            var keyGen = KeyPairGenerator.getInstance("RSA");
            keyGen.initialize(2048);
            var pair = keyGen.generateKeyPair();

            var privateKeyString = convertKeyToString(pair.getPrivate());
            var privateKeyBase64String = Base64.getEncoder().encodeToString(privateKeyString.getBytes());

            openSSLKeyPairHashMap.put("private", privateKeyBase64String);
            // Output private key
            logger.log(Level.INFO, "{0}: SUCCESS -> OpenSSL Private Key Base64 for {1} just created: {2}",
                new Object[]{new Date(), publicIp, privateKeyBase64String});

            // Convert public key to SSH format
            var sshPublicKey = convertPublicKeyToSSHFormat(pair.getPublic());
            openSSLKeyPairHashMap.put("public", sshPublicKey + " wg-public-key");

            logger.log(Level.INFO, "{0}: SUCCESS -> OpenSSL Public Key (SSH Format) for {1} just created: {2} wg-public-key",
                new Object[]{new Date(), publicIp, sshPublicKey});

        } catch (Exception e) {
            logger.log(Level.WARNING, "{0}: FAILURE -> Error generating OpenSSL Key Pair for {1}",
                new Object[]{new Date(), publicIp});
        }

        return openSSLKeyPairHashMap;
    }

    private static String convertKeyToString(Key key) throws IOException {
        var writer = new StringWriter();
        try (var pemWriter = new JcaPEMWriter(writer)) {
            pemWriter.writeObject(key);
        }
        return writer.toString();
    }

    private static String convertPublicKeyToSSHFormat(PublicKey publicKey) throws IOException {
        var rsaPublicKey = (RSAPublicKey) publicKey;
        var byteOs = new ByteArrayOutputStream();
        var dos = new DataOutputStream(byteOs);
        dos.writeInt("ssh-rsa".getBytes().length);
        dos.write("ssh-rsa".getBytes());
        dos.writeInt(rsaPublicKey.getPublicExponent().toByteArray().length);
        dos.write(rsaPublicKey.getPublicExponent().toByteArray());
        dos.writeInt(rsaPublicKey.getModulus().toByteArray().length);
        dos.write(rsaPublicKey.getModulus().toByteArray());
        var publicKeyEncoded = new String(Base64.getEncoder().encode(byteOs.toByteArray()));
        return "ssh-rsa " + publicKeyEncoded;
    }
}
