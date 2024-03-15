package eu.nebulous.service;

import eu.nebulous.dto.ApplicationNodeDto;
import eu.nebulous.dto.LogDto;
import eu.nebulous.model.ApplicationMasterNode;
import eu.nebulous.model.ApplicationWorkerNode;
import eu.nebulous.repository.ApplicationMasterNodeRepository;
import eu.nebulous.repository.ApplicationWorkerNodeRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.UUID;
import java.util.logging.Level;

@ApplicationScoped
public class ApplicationNodeService {
    @Inject
    ApplicationMasterNodeRepository applicationMasterNodeRepository;

    @Inject
    ApplicationWorkerNodeRepository applicationWorkerNodeRepository;

    @Inject
    WGKeyPairGeneratorService wgKeyPairGeneratorService;

    @Inject
    RemoteCodeExecutionService remoteCodeExecutionService;

    @Inject
    LogService logService;

    @ConfigProperty(name = "WIREGUARD_ALLOWED_IPS")
    String wireguardAllowedIps;

    @ConfigProperty(name = "WIREGUARD_DEFAULT_SERVER_IP")
    String wireguardDefaultServerIp;

    @ConfigProperty(name = "WIREGUARD_NETWORK_PORTION")
    String wireguardNetworkPortion;

    @ConfigProperty(name = "WG_BOOTSTRAP_AGENT_SCRIPTS_DIR")
    String wgBootstrapAgentScriptsDir;

    private static final String ONM = "ONM";

    private void persistApplicationMasterNode(List<LogDto> logList, ApplicationNodeDto applicationNodeDto, String openSSLPrivateKey, String openSSLPublicKey,
                                              String wireguardPrivateKey, String wireguardPublicKey) {
        try {
            var applicationMasterNode = new ApplicationMasterNode();
            applicationMasterNode.setUuid(UUID.randomUUID().toString());
            applicationMasterNode.setPublicIp(applicationNodeDto.publicIp());
            applicationMasterNode.setApplicationUUID(applicationNodeDto.applicationUUID());
            applicationMasterNode.setSshUsername(applicationNodeDto.sshUsername());
            applicationMasterNode.setDateCreated(new Date());
            applicationMasterNode.setOpenSSLPrivateKey(openSSLPrivateKey);
            applicationMasterNode.setOpenSSLPublicKey(openSSLPublicKey);
            applicationMasterNode.setWireguardPrivateKey(wireguardPrivateKey);
            applicationMasterNode.setWireguardPublicKey(wireguardPublicKey);
            applicationMasterNode.setWireguardOverlaySubnet(wireguardAllowedIps);
            applicationMasterNode.setWireguardIp(wireguardDefaultServerIp);

            applicationMasterNodeRepository.persist(applicationMasterNode);

            logService.log(logList, Level.INFO, ONM, "SUCCESS -> Application Node Master (" + applicationNodeDto.publicIp() +
                "," + applicationNodeDto.applicationUUID() + ") successfully persisted to DB!");
        } catch (Exception e) {
            logService.log(logList, Level.WARNING, ONM, "FAILURE -> The Application Node Master (" + applicationNodeDto.publicIp() +
                "," + applicationNodeDto.applicationUUID() + ") failed to be persisted to DB!");
        }
    }

    private void persistApplicationWorkerNode(List<LogDto> logList, ApplicationNodeDto applicationNodeDto, ApplicationMasterNode masterNode,
                                              String wireguardPrivateKey, String wireguardPublicKey, String wireguardWorkerIp) {
        try {
            var applicationWorkerNode = new ApplicationWorkerNode();
            applicationWorkerNode.setUuid(UUID.randomUUID().toString());
            applicationWorkerNode.setSshUsername(applicationNodeDto.sshUsername());
            applicationWorkerNode.setPublicIp(applicationNodeDto.publicIp());
            applicationWorkerNode.setApplicationMasterNode(masterNode);
            applicationWorkerNode.setDateCreated(new Date());
            applicationWorkerNode.setWireguardPrivateKey(wireguardPrivateKey);
            applicationWorkerNode.setWireguardPublicKey(wireguardPublicKey);
            applicationWorkerNode.setWireguardIp(wireguardWorkerIp);
            applicationWorkerNode.setOpenSSLPrivateKey(applicationNodeDto.privateKeyBase64());
            applicationWorkerNode.setOpenSSLPublicKey(applicationNodeDto.publicKey());

            applicationWorkerNodeRepository.persist(applicationWorkerNode);

            logService.log(logList, Level.INFO, ONM, "SUCCESS -> Application Node Worker (" + applicationNodeDto.publicIp() +
                "," + applicationNodeDto.applicationUUID() + ") successfully persisted to DB!");
        } catch (Exception e) {
            logService.log(logList, Level.WARNING, ONM, "FAILURE -> The Application Node Worker (" + applicationNodeDto.publicIp() +
                "," + applicationNodeDto.applicationUUID() + ") failed to be persisted to DB!");
        }
    }

    @Transactional
    public List<LogDto> evaluateNodeCreation(ApplicationNodeDto applicationNodeDto) {
        var logList = new ArrayList<LogDto>();

        // Create WG Key Pair Function
        var wireguardKeyPair = wgKeyPairGeneratorService.createWireguardKeyPair(applicationNodeDto.publicIp());
        var wireguardPrivateKey = wireguardKeyPair.get("private");
        var wireguardPublicKey = wireguardKeyPair.get("public");

        logService.log(logList, Level.INFO, ONM, "Created WG Key Pair for Application Node with Public IP: " + applicationNodeDto.publicIp());

        if (applicationNodeDto.isMaster().equals(Boolean.TRUE)) {
            logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-server-create.sh ------------------------------------");
            logService.log(logList, Level.INFO, ONM, "SCP FILE wg-server-create.sh to HOST: " + applicationNodeDto.publicIp());

            remoteCodeExecutionService.scpFile(applicationNodeDto.sshUsername(),applicationNodeDto.publicIp(),
                22,applicationNodeDto.privateKeyBase64(),30L,
                wgBootstrapAgentScriptsDir + "/server/wg-server-create.sh",
                "wireguard",null);
            logService.log(logList, Level.INFO, ONM, "SCP COMPLETED! Ready to run wg-server-create.sh to HOST: " + applicationNodeDto.publicIp());

            var permissionsCommand = "sudo chmod +x /home/" + applicationNodeDto.sshUsername() + "/wireguard/wg-server-create.sh";
            var executeCommand = "sudo /home/" + applicationNodeDto.sshUsername() + "/wireguard/wg-server-create.sh " + wireguardPrivateKey + " " +
                wireguardPublicKey + " " + " " + wireguardDefaultServerIp;
            remoteCodeExecutionService.runCommand(applicationNodeDto.sshUsername(),applicationNodeDto.privateKeyBase64(),applicationNodeDto.publicIp(),
                22,30L,
                permissionsCommand + ";" + executeCommand, null);
            logService.log(logList, Level.INFO, ONM, "COMMAND wg-server-create.sh for HOST " + applicationNodeDto.publicIp() + " COMPLETED!");
            logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-server-create.sh ------------------------------------");

            // Persist to DB
            persistApplicationMasterNode(logList, applicationNodeDto, applicationNodeDto.privateKeyBase64(), applicationNodeDto.publicKey(),
                wireguardPrivateKey, wireguardPublicKey);
        } else {
            String wireguardWorkerIp = wireguardNetworkPortion + "2";
            ApplicationMasterNode masterNode = applicationMasterNodeRepository.findByApplicationUUID(applicationNodeDto.applicationUUID());
            if (masterNode != null) {
                List<ApplicationWorkerNode> workerNodes = applicationWorkerNodeRepository.findWorkerNodesByMasterNode(masterNode);

                logService.log(logList, Level.INFO, ONM, "Worker Nodes " + workerNodes.size());

                if (!workerNodes.isEmpty()) wireguardWorkerIp = wireguardNetworkPortion + (workerNodes.size() + 2);
                var workerNodeClientName = "wg" + wireguardWorkerIp;

                logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-client-create_server.sh ------------------------------------");
                logService.log(logList, Level.INFO, ONM, "SCP FILE wg-client-create_server.sh to HOST: " + masterNode.getPublicIp());

                remoteCodeExecutionService.scpFile(masterNode.getSshUsername(),masterNode.getPublicIp(),
                    22, masterNode.getOpenSSLPrivateKey(), 30L,
                     wgBootstrapAgentScriptsDir + "/client/wg-client-create_server.sh",
                    "wireguard",null);
                logService.log(logList, Level.INFO, ONM, "SCP COMPLETED! Ready to run wg-client-create_server.sh to HOST: " + masterNode.getPublicIp());
                var permissionsCommandServer = "sudo chmod +x /home/" + masterNode.getSshUsername() + "/wireguard/wg-client-create_server.sh";
                var executeCommandServer = "sudo /home/" + masterNode.getSshUsername() + "/wireguard/wg-client-create_server.sh " + workerNodeClientName + " " + wireguardPrivateKey + " " +
                    wireguardPublicKey + " " + masterNode.getSshUsername() + " " +  masterNode.getWireguardPublicKey() + " " + masterNode.getPublicIp()+":"+"51820" + " " +
                    wireguardWorkerIp + " " + wireguardAllowedIps;
                remoteCodeExecutionService.runCommand(masterNode.getSshUsername(),masterNode.getOpenSSLPrivateKey(),masterNode.getPublicIp(),
                    22,30L,
                    permissionsCommandServer + ";" + executeCommandServer, null);
                logService.log(logList, Level.INFO, ONM, "COMMAND wg-client-create_server.sh for HOST " + masterNode.getPublicIp() + " COMPLETED!");
                logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-client-create_server.sh ------------------------------------");

                logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-client-create_client.sh ------------------------------------");
                remoteCodeExecutionService.scpFile(applicationNodeDto.sshUsername(),applicationNodeDto.publicIp(),
                    22,applicationNodeDto.privateKeyBase64(),30L,
                    wgBootstrapAgentScriptsDir + "/client/wg-client-create_client.sh",
                    "wireguard",null);
                logService.log(logList, Level.INFO, ONM, "SCP COMPLETED! Ready to run wg-client-create_client.sh to HOST: " + applicationNodeDto.publicIp());
                var permissionsCommandClient = "sudo chmod +x /home/" + applicationNodeDto.sshUsername() + "/wireguard/wg-client-create_client.sh";
                var executeCommandClient = "sudo /home/" + applicationNodeDto.sshUsername() + "/wireguard/wg-client-create_client.sh " + applicationNodeDto.sshUsername() + " " +
                    "\"" + masterNode.getOpenSSLPrivateKey() + "\"  " + masterNode.getPublicIp() + " " + workerNodeClientName + " " + masterNode.getSshUsername();
                remoteCodeExecutionService.runCommand(applicationNodeDto.sshUsername(),applicationNodeDto.privateKeyBase64(),applicationNodeDto.publicIp(),
                    22,30L, permissionsCommandClient + ";" + executeCommandClient, null);
                logService.log(logList, Level.INFO, ONM, "COMMAND wg-client-create_client.sh for HOST " + applicationNodeDto.publicIp() + " COMPLETED!");

                logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-client-create_client.sh ------------------------------------");

                // Persist to DB
                persistApplicationWorkerNode(logList, applicationNodeDto, masterNode, wireguardPrivateKey, wireguardPublicKey, wireguardWorkerIp);
            }
        }

        return logList;
    }

    @Transactional
    public List<LogDto> evaluateNodeDeletion(ApplicationNodeDto applicationNodeDto) {
        var logList = new ArrayList<LogDto>();

        if(applicationNodeDto.isMaster().equals(Boolean.TRUE)) {
            ApplicationMasterNode masterNode = applicationMasterNodeRepository.findByApplicationUUID(applicationNodeDto.applicationUUID());
            if (masterNode == null) {
                logService.log(logList, Level.INFO, ONM, "FAILURE -> Could not find an Application Master Node with applicationUUID " +
                    applicationNodeDto.applicationUUID());

                return logList;
            }

            // Check If Master has workers below him
            List<ApplicationWorkerNode> workerNodes = applicationWorkerNodeRepository.findWorkerNodesByMasterNode(masterNode);
            if(workerNodes.isEmpty()) {
                logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-server-delete.sh ------------------------------------");
                logService.log(logList, Level.INFO, ONM, "SCP FILE wg-server-delete.sh to HOST: " + applicationNodeDto.publicIp());

                remoteCodeExecutionService.scpFile(applicationNodeDto.sshUsername(),applicationNodeDto.publicIp(),
                    22,applicationNodeDto.privateKeyBase64(),30L,
                    wgBootstrapAgentScriptsDir + "/server/wg-server-delete.sh",
                    "wireguard",null);
                logService.log(logList, Level.INFO, ONM, "SCP COMPLETED! Ready to run wg-server-delete.sh to HOST: " + applicationNodeDto.publicIp());
                var permissionsCommand = "sudo chmod +x /home/" + applicationNodeDto.sshUsername() + "/wireguard/wg-server-delete.sh";
                var executeCommand = "sudo /home/" + applicationNodeDto.sshUsername() + "/wireguard/wg-server-delete.sh " + applicationNodeDto.sshUsername();
                remoteCodeExecutionService.runCommand(applicationNodeDto.sshUsername(),applicationNodeDto.privateKeyBase64(),applicationNodeDto.publicIp(),
                    22,30L,
                    permissionsCommand + ";" + executeCommand, null);
                logService.log(logList, Level.INFO, ONM, "COMMAND wg-server-delete.sh for HOST " + applicationNodeDto.publicIp() + " COMPLETED!");
                logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-server-delete.sh ------------------------------------");
                deleteApplicationMasterNode(logList, masterNode);
            } else {
                logService.log(logList, Level.INFO, ONM, "The Application Master Node with PublicIP " + applicationNodeDto.publicIp() +
                    " and applicationUUID " + applicationNodeDto.applicationUUID() + " has " + workerNodes.size() + " worker nodes.");
                //TODO: What happens when a request for deletion on a WG Server appears and it has workers running??
            }
        } else {
            var workerNode = applicationWorkerNodeRepository.findWorkerByPublicIp(applicationNodeDto);
            if(workerNode == null) {
                logService.log(logList, Level.INFO, ONM, "FAILURE -> Could not find an Application Worker Node with applicationUUID " + applicationNodeDto.publicIp());
                return logList;
            }

            logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-client-delete_client.sh ------------------------------------");
            logService.log(logList, Level.INFO, ONM, "SCP FILE wg-client-delete_client.sh to HOST: " + applicationNodeDto.publicIp());
            remoteCodeExecutionService.scpFile(applicationNodeDto.sshUsername(),applicationNodeDto.publicIp(),
                22,applicationNodeDto.privateKeyBase64(),30L,
                wgBootstrapAgentScriptsDir + "/client/wg-client-delete_client.sh",
                "wireguard",null);
            logService.log(logList, Level.INFO, ONM, "SCP COMPLETED! Ready to run wg-client-delete_client_script.sh to HOST: " + applicationNodeDto.publicIp());
            var permissionsCommandClient = "sudo chmod +x /home/" + applicationNodeDto.sshUsername() + "/wireguard/wg-client-delete_client.sh";
            var executeCommandClient = "sudo /home/" + applicationNodeDto.sshUsername() + "/wireguard/wg-client-delete_client.sh " + applicationNodeDto.sshUsername() +
                " " + "wg" + workerNode.getWireguardIp();
            remoteCodeExecutionService.runCommand(applicationNodeDto.sshUsername(),applicationNodeDto.privateKeyBase64(),applicationNodeDto.publicIp(),
                22,30L,
                permissionsCommandClient + ";" + executeCommandClient, null);
            logService.log(logList, Level.INFO, ONM, "COMMAND wg-client-delete_client.sh for HOST " + applicationNodeDto.publicIp() + " COMPLETED!");
            logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-client-delete_client.sh ------------------------------------");

            logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-client-delete_server.sh ------------------------------------");
            logService.log(logList, Level.INFO, ONM, "SCP FILE wg-client-delete_server.sh to HOST: " + workerNode.getApplicationMasterNode().getPublicIp());
            remoteCodeExecutionService.scpFile(workerNode.getApplicationMasterNode().getSshUsername(),workerNode.getApplicationMasterNode().getPublicIp(),
                22,workerNode.getApplicationMasterNode().getOpenSSLPrivateKey(),30L,
                wgBootstrapAgentScriptsDir + "/client/wg-client-delete_server.sh",
                "wireguard",null);
            logService.log(logList, Level.INFO, ONM, "SCP COMPLETED! Ready to run wg-client-delete_server.sh to HOST: " + workerNode.getApplicationMasterNode().getPublicIp());
            var permissionsCommandServer = "sudo chmod +x /home/" + workerNode.getApplicationMasterNode().getSshUsername() + "/wireguard/wg-client-delete_server.sh";
            var executeCommandServer = "sudo /home/" + workerNode.getApplicationMasterNode().getSshUsername() + "/wireguard/wg-client-delete_server.sh " + "wg" + workerNode.getWireguardIp() +
                " " + workerNode.getWireguardPublicKey() + " " + applicationNodeDto.sshUsername();
            remoteCodeExecutionService.runCommand(workerNode.getApplicationMasterNode().getSshUsername(),workerNode.getApplicationMasterNode().getOpenSSLPrivateKey(),
                workerNode.getApplicationMasterNode().getPublicIp(),22,30L, permissionsCommandServer + ";" + executeCommandServer, null);
            logService.log(logList, Level.INFO, ONM, "COMMAND wg-client-delete_server.sh for HOST " + applicationNodeDto.publicIp() + " COMPLETED!");
            logService.log(logList, Level.INFO, ONM, "------------------------------------ wg-client-delete_server.sh ------------------------------------");

            deleteApplicationWorkerNode(logList, workerNode);
        }

        return logList;
    }

    private void deleteApplicationMasterNode(List<LogDto> logList, ApplicationMasterNode masterNode) {
        try {
            applicationMasterNodeRepository.delete(masterNode);
            logService.log(logList, Level.INFO, ONM, "SUCCESS -> Application Node Master (" + masterNode.getPublicIp()  + ", " +
                masterNode.getApplicationUUID() + ") successfully deleted from the DB!");
        } catch (Exception e) {
            logService.log(logList, Level.WARNING, ONM, "FAILURE -> The Application Node Master (" + masterNode.getPublicIp()  + ", " +
                masterNode.getApplicationUUID() + ") failed to be deleted from the DB!");
        }
    }

    private void deleteApplicationWorkerNode(List<LogDto> logList, ApplicationWorkerNode workerNode) {
        try {
            applicationWorkerNodeRepository.delete(workerNode);
            logService.log(logList, Level.INFO, ONM, "SUCCESS -> Application Node Worker (" + workerNode.getPublicIp()  + ", " +
                workerNode.getApplicationMasterNode().getApplicationUUID() + ") successfully deleted from the DB!");
        } catch (Exception e) {
            logService.log(logList, Level.WARNING, ONM, "FAILURE -> The Application Node Worker (" + workerNode.getPublicIp()  + ", " +
                workerNode.getApplicationMasterNode().getApplicationUUID() + ") failed to be deleted from the DB!");
        }
    }
}
