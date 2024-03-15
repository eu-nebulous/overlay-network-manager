package eu.nebulous.service;

import jakarta.enterprise.context.ApplicationScoped;
import org.bouncycastle.crypto.generators.X25519KeyPairGenerator;
import org.bouncycastle.crypto.params.X25519KeyGenerationParameters;
import org.bouncycastle.crypto.params.X25519PrivateKeyParameters;
import org.bouncycastle.crypto.params.X25519PublicKeyParameters;
import org.bouncycastle.util.encoders.Base64;

import java.security.SecureRandom;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

@ApplicationScoped
public class WGKeyPairGeneratorService {

    private static final Logger logger = Logger.getLogger(WGKeyPairGeneratorService.class.getName());

    public Map<String, String> createWireguardKeyPair(String publicIp) {
        var wireguardKeyPairHashMap = new HashMap<String, String>();
        // Initialize key generator
        var keyPairGenerator = new X25519KeyPairGenerator();
        keyPairGenerator.init(new X25519KeyGenerationParameters(new SecureRandom()));

        // Generate key pair
        var keyPair = keyPairGenerator.generateKeyPair();

        // Extract private and public keys
        var privateKey = (X25519PrivateKeyParameters) keyPair.getPrivate();
        var publicKey = (X25519PublicKeyParameters) keyPair.getPublic();

        // Encode keys to Base64
        var privateKeyBase64 = Base64.toBase64String(privateKey.getEncoded());
        var publicKeyBase64 = Base64.toBase64String(publicKey.getEncoded());

        wireguardKeyPairHashMap.put("private", privateKeyBase64);
        wireguardKeyPairHashMap.put("public", publicKeyBase64);

        // Output the keys
        logger.log(Level.INFO, "{0}: SUCCESS -> Private Key for {1} just created: {2}",
            new Object[]{new Date(), publicIp, privateKeyBase64});
        logger.log(Level.INFO, "{0}: SUCCESS -> Public Key for {1} just created: {2}",
            new Object[]{new Date(), publicIp, publicKeyBase64});

        return wireguardKeyPairHashMap;
    }
}
