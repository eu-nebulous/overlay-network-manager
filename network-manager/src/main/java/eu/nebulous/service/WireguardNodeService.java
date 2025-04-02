package eu.nebulous.service;

import eu.nebulous.dto.WireguardNodeDto;
import eu.nebulous.dto.LogDto;
import eu.nebulous.dto.WireguardPeerDto;
import eu.nebulous.model.WireguardNode;
import eu.nebulous.repository.WireguardNodeRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;
import java.util.logging.Level;

@ApplicationScoped
public class WireguardNodeService {
	@Inject
	WireguardNodeRepository wireguardNodeRepository;

	@Inject
	WGKeyPairGeneratorService wgKeyPairGeneratorService;

	@Inject
	RemoteCodeExecutionService remoteCodeExecutionService;

	@Inject
	LogService logService;

	@ConfigProperty(name = "WIREGUARD_NETWORK_PORTION")
	String wireguardNetworkPortion;

	@ConfigProperty(name = "WG_BOOTSTRAP_AGENT_SCRIPTS_DIR")
	String wgBootstrapAgentScriptsDir;

	private static final String ONM = "ONM";
	
	// Lock for synchronizing node registration operations
	private final Lock registrationLock = new ReentrantLock();

	private void persistWireguardNode(List<LogDto> logList, WireguardNodeDto wireguardNodeDto, String openSSLPrivateKey, String openSSLPublicKey,
                                  	String wireguardPrivateKey, String wireguardPublicKey, String wireguardNodeIp) {
    	try {
        	var wireguardNode = new WireguardNode();
        	wireguardNode.setUuid(UUID.randomUUID().toString());
        	wireguardNode.setPublicIp(wireguardNodeDto.publicIp());
        	wireguardNode.setApplicationUUID(wireguardNodeDto.applicationUUID());
        	wireguardNode.setSshUsername(wireguardNodeDto.sshUsername());
        	wireguardNode.setSshPort(Integer.parseInt(wireguardNodeDto.sshPort()));
        	wireguardNode.setDateCreated(new Date());
        	wireguardNode.setOpenSSLPrivateKey(openSSLPrivateKey);
        	wireguardNode.setOpenSSLPublicKey(openSSLPublicKey);
        	wireguardNode.setWireguardPrivateKey(wireguardPrivateKey);
        	wireguardNode.setWireguardPublicKey(wireguardPublicKey);
        	wireguardNode.setWireguardIp(wireguardNodeIp);

        	wireguardNodeRepository.persist(wireguardNode);

        	logService.log(logList, Level.INFO, ONM, "SUCCESS -> Wireguard Node (" + wireguardNodeDto.publicIp() +
            	"," + wireguardNodeDto.applicationUUID() + ") successfully persisted to DB!");
    	} catch (Exception e) {
        	logService.log(logList, Level.WARNING, ONM, "FAILURE -> The Wireguard Node (" + wireguardNodeDto.publicIp() +
            	"," + wireguardNodeDto.applicationUUID() + ") failed to be persisted to DB!");
    	}
	}

	private void deleteWireguardNode(List<LogDto> logList, WireguardNode wireguardNode) {
    	try {
        	wireguardNodeRepository.delete(wireguardNode);
        	logService.log(logList, Level.INFO, ONM, "SUCCESS -> Wireguard Node (" + wireguardNode.getPublicIp()  + ", " +
            	wireguardNode.getApplicationUUID() + ") successfully deleted from the DB!");
    	} catch (Exception e) {
        	logService.log(logList, Level.WARNING, ONM, "FAILURE -> Wireguard Node (" + wireguardNode.getPublicIp()  + ", " +
            	wireguardNode.getApplicationUUID() + ") failed to be deleted from the DB!");
    	}
	}
  
        @Transactional
	NodeRegistrationData prepareWireguardNodeRegistration(WireguardNodeDto wireguardNodeDto) {
    	var logList = new ArrayList<LogDto>();
    	
    	// Acquire lock to ensure thread safety during node registration
    	registrationLock.lock();
    	try {
    		logService.log(logList, Level.INFO, ONM, "Acquired lock for node registration with IP: " + wireguardNodeDto.publicIp());
    		
        	// Fetch Wireguard Nodes based on Application UUID
        	var wireguardNodeList = wireguardNodeRepository.fetchNodeListByApplicationUUID(wireguardNodeDto.applicationUUID());

        	var wireguardNodeIp = wireguardNetworkPortion + (wireguardNodeList.size() + 1);

        	// Create WG Key Pair
        	var wireguardKeyPair = wgKeyPairGeneratorService.createWireguardKeyPair(wireguardNodeDto.publicIp());
        	var wireguardPrivateKey = wireguardKeyPair.get("private");
        	var wireguardPublicKey = wireguardKeyPair.get("public");

        	logService.log(logList, Level.INFO, ONM, "Created WG Key Pair for Application Node with Public IP: " + wireguardNodeDto.publicIp());
            
            // Persist Transaction to DB
        	persistWireguardNode(logList, wireguardNodeDto, wireguardNodeDto.privateKeyBase64(), wireguardNodeDto.publicKey(),
            	wireguardPrivateKey, wireguardPublicKey, wireguardNodeIp);

        	return new NodeRegistrationData(logList, wireguardPrivateKey, wireguardPublicKey, wireguardNodeIp);
    	} finally {
    		// Always release the lock, even if an exception occurs
    		registrationLock.unlock();
    		logService.log(logList, Level.INFO, ONM, "Released lock for node registration with IP: " + wireguardNodeDto.publicIp());
    	}
	}

	private void executeNodeRegistrationScript(NodeRegistrationData registrationData, WireguardNodeDto wireguardNodeDto) {
    	var logList = registrationData.logList();
        var wireguardPrivateKey = registrationData.wireguardPrivateKey();
        var wireguardPublicKey = registrationData.wireguardPublicKey();
        var wireguardNodeIp = registrationData.wireguardNodeIp();
        
    	var registerNodeScript = "wg-register-node.sh";
    	logService.log(logList, Level.INFO, ONM, "------------------------------------ " + registerNodeScript + " ------------------------------------");

    	logService.log(logList, Level.INFO, ONM, "SCP FILE " + registerNodeScript + " to HOST: " + wireguardNodeDto.publicIp());
    	remoteCodeExecutionService.scpFile(logList, wireguardNodeDto.sshUsername(), wireguardNodeDto.publicIp(),
        	Integer.parseInt(wireguardNodeDto.sshPort()), wireguardNodeDto.privateKeyBase64(),30L,
        	wgBootstrapAgentScriptsDir + "/" + registerNodeScript,
        	"wireguard",null);
    	logService.log(logList, Level.INFO, ONM, "SCP COMPLETED! Ready to run " + registerNodeScript + " to HOST: " + wireguardNodeDto.publicIp());

    	var permissionsCommand = "sudo chmod +x /home/" + wireguardNodeDto.sshUsername() + "/wireguard/" + registerNodeScript;
    	var executeCommand = "sudo /home/" + wireguardNodeDto.sshUsername() + "/wireguard/" + registerNodeScript + " " + wireguardPrivateKey + " " +
        	wireguardPublicKey + " " + wireguardNodeIp;
    	remoteCodeExecutionService.runCommand(logList, wireguardNodeDto.sshUsername(), wireguardNodeDto.privateKeyBase64(), wireguardNodeDto.publicIp(),
        	Integer.parseInt(wireguardNodeDto.sshPort()),30L,
        	permissionsCommand + ";" + executeCommand, null);

    	logService.log(logList, Level.INFO, ONM, "COMMAND " + registerNodeScript + " for HOST " + wireguardNodeDto.publicIp() + " COMPLETED!");
    	logService.log(logList, Level.INFO, ONM, "------------------------------------ " + registerNodeScript + " ------------------------------------");
	}

	public List<LogDto> registerWireguardNode(WireguardNodeDto wireguardNodeDto) {
    	// First prepare the node registration and get the required data
    	var registrationData = prepareWireguardNodeRegistration(wireguardNodeDto);
    	
    	// Then execute the registration script on the remote host
    	executeNodeRegistrationScript(registrationData, wireguardNodeDto);

    	// Return the logs
    	return registrationData.logList();
	}

	@Transactional
	public List<LogDto> deregisterWireguardNode(String wireguardNodeIp, String applicationUUID) {
    	var logList = new ArrayList<LogDto>();

    	var wireguardNode = wireguardNodeRepository
        	.findByWireguardNodeIpAndApplicationUUID(wireguardNodeIp, applicationUUID);
    	if (wireguardNode == null) {
        	logService.log(logList, Level.WARNING, ONM, "Wireguard Node with IP " + wireguardNodeIp + " and " +
            	"Application UUID: " + applicationUUID  + " not found. Exiting...");
        	return logList;
    	}

    	var deregisterNodeScript = "wg-deregister-node.sh";
    	logService.log(logList, Level.INFO, ONM, "------------------------------------ " + deregisterNodeScript + " ------------------------------------");

    	logService.log(logList, Level.INFO, ONM, "SCP FILE " + deregisterNodeScript + " to HOST: " + wireguardNode.getPublicIp());
    	remoteCodeExecutionService.scpFile(logList, wireguardNode.getSshUsername(), wireguardNode.getPublicIp(),
        	wireguardNode.getSshPort(), wireguardNode.getOpenSSLPrivateKey(),30L,
        	wgBootstrapAgentScriptsDir + "/" + deregisterNodeScript,
        	"wireguard",null);
    	logService.log(logList, Level.INFO, ONM, "SCP COMPLETED! Ready to run " + deregisterNodeScript + " to HOST: " + wireguardNode.getPublicIp());

    	var permissionsCommand = "sudo chmod +x /home/" + wireguardNode.getSshUsername() + "/wireguard/" + deregisterNodeScript;
    	var executeCommand = "sudo /home/" + wireguardNode.getSshUsername() + "/wireguard/" + deregisterNodeScript + " " + wireguardNode.getSshUsername() + " " +
        	wireguardNodeIp;
    	remoteCodeExecutionService.runCommand(logList, wireguardNode.getSshUsername(),wireguardNode.getOpenSSLPrivateKey(),
        	wireguardNode.getPublicIp(), wireguardNode.getSshPort(),30L,
        	permissionsCommand + ";" + executeCommand, null);
    	logService.log(logList, Level.INFO, ONM, "COMMAND " + deregisterNodeScript + " for HOST " + wireguardNode.getPublicIp() + " COMPLETED!");

    	logService.log(logList, Level.INFO, ONM, "------------------------------------ " + deregisterNodeScript + " ------------------------------------");

    	// Persist Transaction to DB
    	deleteWireguardNode(logList, wireguardNode);

    	return logList;
	}

	public List<WireguardPeerDto> fetchNodeListByApplicationUUIDAndWireguardIp(String wireguardIp, String applicationUUID) {
    	var wireguardPeerDtoList = new ArrayList<WireguardPeerDto>();

    	// Check if Wireguard Node Exists
    	var wgNode = wireguardNodeRepository.fetchNodeByWireguardIp(wireguardIp);
    	if (wgNode == null) return wireguardPeerDtoList;

    	// Fetch Wireguard Nodes based on Application UUID
    	var wireguardNodeList = wireguardNodeRepository
        	.fetchNodeListByApplicationUUID(applicationUUID);
    	if (wireguardNodeList.isEmpty()) return wireguardPeerDtoList;

    	for(WireguardNode wireguardNode: wireguardNodeList) {
        	// Fetch only peers and not itself
        	if (wireguardNode.getWireguardIp().equals(wireguardIp)) continue;

        	wireguardPeerDtoList.add(new WireguardPeerDto(
            	wireguardNode.getWireguardPublicKey(),
            	wireguardNode.getPublicIp(),
            	wireguardNode.getWireguardIp()
        	));
    	}

    	return wireguardPeerDtoList;
	}
	
	// Record to hold data between the two split functions
	private record NodeRegistrationData(
	    List<LogDto> logList,
	    String wireguardPrivateKey,
	    String wireguardPublicKey,
	    String wireguardNodeIp
	) {}
}
