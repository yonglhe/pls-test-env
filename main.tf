###############################
#           Consumer          #
###############################
resource "azurerm_resource_group" "consumer" {
  name     = "${var.prefix_name}-consumer-rg"
  location = var.location
}

resource "azurerm_virtual_network" "consumer" {
  name                = "${var.prefix_name}-consumer-vnet"
  location            = azurerm_resource_group.consumer.location
  resource_group_name = azurerm_resource_group.consumer.name
  address_space       = ["10.0.0.0/16"]
}

# SECURITY FOR CONSUMER
resource "azurerm_network_security_group" "consumer_nsg" {
  name                = "${var.prefix_name}-consumer-nsg"
  location            = azurerm_resource_group.consumer.location
  resource_group_name = azurerm_resource_group.consumer.name

  # Inbound rule - Allow ICMP
  security_rule {
    name                       = "AllowICMP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Inbound rule - Allow SSH (TCP 22)
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Outbound rule - Allow traffic to Private Link subnet
  security_rule {
    name                       = "AllowPrivateLink"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.0.2.0/24"
  }
}

resource "azurerm_network_interface_security_group_association" "consumer_nsg" {
  network_interface_id      = azurerm_network_interface.consumer_nic.id
  network_security_group_id = azurerm_network_security_group.consumer_nsg.id
}


# PRIVATE ENDPOINT FOR CONSUMER
resource "azurerm_subnet" "consumer_private_endpoint_subnet" {
  name                              = "${var.prefix_name}-consumer-pe-subnet"
  resource_group_name               = azurerm_resource_group.consumer.name
  virtual_network_name              = azurerm_virtual_network.consumer.name
  address_prefixes                  = ["10.0.2.0/24"]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_private_endpoint" "main" {
  name                = "${var.prefix_name}-consumer-pe"
  location            = azurerm_resource_group.consumer.location
  resource_group_name = azurerm_resource_group.consumer.name
  subnet_id           = azurerm_subnet.consumer_private_endpoint_subnet.id

  private_service_connection {
    name                           = "pls-connection"
    private_connection_resource_id = azurerm_private_link_service.provider.id
    is_manual_connection           = false
  }
}

# PUBLIC IP FOR CONSUMER
resource "azurerm_public_ip" "consumer_pip" {
  name                = "${var.prefix_name}-consumer-pip"
  location            = azurerm_resource_group.consumer.location
  resource_group_name = azurerm_resource_group.consumer.name

  allocation_method = "Static"
  sku               = "Standard"
  ip_version        = "IPv4"
}

resource "azurerm_network_interface" "consumer_nic" {
  name                = "${var.prefix_name}-consumer-nic"
  location            = azurerm_resource_group.consumer.location
  resource_group_name = azurerm_resource_group.consumer.name

  ip_configuration {
    name                          = "Internal"
    subnet_id                     = azurerm_subnet.consumer_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.consumer_pip.id
  }
}

# VIRTUAL MACHINE FOR CONSUMER
resource "azurerm_subnet" "consumer_subnet" {
  name                            = "${var.prefix_name}-consumer-subnet"
  resource_group_name             = azurerm_resource_group.consumer.name
  virtual_network_name            = azurerm_virtual_network.consumer.name
  address_prefixes                = ["10.0.1.0/24"]
  default_outbound_access_enabled = true
}

resource "azurerm_linux_virtual_machine" "consumer" {
  name                            = "${var.prefix_name}-consumer-vm"
  resource_group_name             = azurerm_resource_group.consumer.name
  location                        = azurerm_resource_group.consumer.location
  size                            = "Standard_B2s"
  admin_username                  = "consumer-user"
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.consumer_nic.id]

  admin_ssh_key {
    username   = "consumer-user"
    public_key = file("~/.ssh/consumer_vm_key.pub")
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}



###############################
#           Provider          #
###############################
resource "azurerm_resource_group" "provider" {
  name     = "${var.prefix_name}-provider-rg"
  location = var.location
}

resource "azurerm_virtual_network" "provider" {
  name                = "${var.prefix_name}-provider-vnet"
  location            = azurerm_resource_group.provider.location
  resource_group_name = azurerm_resource_group.provider.name
  address_space       = ["192.168.0.0/16"]
}


# SECURITY FOR THE PROVIDER
resource "azurerm_network_security_group" "provider_nsg" {
  name                = "${var.prefix_name}-provider-nsg"
  location            = azurerm_resource_group.provider.location
  resource_group_name = azurerm_resource_group.provider.name

  # Inbound rule - Allow ICMP
  security_rule {
    name                       = "AllowICMP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Inbound rule - Allow SSH (TCP 22)
  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Inbound rule - Allow HTTP (TCP 80)
  security_rule {
    name                       = "HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Inbound rule - Allow Load Balancer Probe (TCP 80)
  security_rule {
    name                       = "LoadBalancerProbe"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "provider_nsg" {
  network_interface_id      = azurerm_network_interface.provider_nic.id
  network_security_group_id = azurerm_network_security_group.provider_nsg.id
}

# STANDARD LOAD BALANCER FOR PROVIDER
resource "azurerm_subnet" "load_balancer_subnet" {
  name                 = "${var.prefix_name}-provider-lb-subnet"
  resource_group_name  = azurerm_resource_group.provider.name
  virtual_network_name = azurerm_virtual_network.provider.name
  address_prefixes     = ["192.168.2.0/24"]
}

resource "azurerm_lb" "main" {
  name                = "${var.prefix_name}-provider-load-balancer"
  location            = azurerm_resource_group.provider.location
  resource_group_name = azurerm_resource_group.provider.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.load_balancer_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  name            = "backend-pool"
  loadbalancer_id = azurerm_lb.main.id
}

resource "azurerm_network_interface_backend_address_pool_association" "provider" {
  network_interface_id    = azurerm_network_interface.provider_nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

resource "azurerm_lb_probe" "http" {
  name                = "${var.prefix_name}-http-probe"
  loadbalancer_id     = azurerm_lb.main.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 15
  number_of_probes    = 2
  probe_threshold     = 1
}

resource "azurerm_lb_rule" "http" {
  name                           = "${var.prefix_name}-http-rule"
  loadbalancer_id                = azurerm_lb.main.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.main.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.http.id

  idle_timeout_in_minutes = 4
  load_distribution       = "Default"
  disable_outbound_snat   = false
}

# PRIVATE LINK SERVICE FOR PROVIDER
resource "azurerm_subnet" "private_link_subnet" {
  name                                          = "${var.prefix_name}-provider-pl-subnet"
  resource_group_name                           = azurerm_resource_group.provider.name
  virtual_network_name                          = azurerm_virtual_network.provider.name
  address_prefixes                              = ["192.168.3.0/24"]
  private_link_service_network_policies_enabled = false
}

resource "azurerm_private_link_service" "provider" {
  name                = "${var.prefix_name}-provider-private-link-service"
  location            = azurerm_resource_group.provider.location
  resource_group_name = azurerm_resource_group.provider.name
  # auto_approval_subscription_ids = [data.azurerm_client_config.current.subscription_id] # optional

  nat_ip_configuration {
    name                       = "primary"
    primary                    = true
    private_ip_address_version = "IPv4"
    subnet_id                  = azurerm_subnet.private_link_subnet.id
  }

  load_balancer_frontend_ip_configuration_ids = [azurerm_lb.main.frontend_ip_configuration[0].id]
}


# PUBLIC IP FOR PROVIDER
resource "azurerm_public_ip" "provider_pip" {
  name                = "${var.prefix_name}-provider-pip"
  location            = azurerm_resource_group.provider.location
  resource_group_name = azurerm_resource_group.provider.name

  allocation_method = "Static"
  sku               = "Standard"
  ip_version        = "IPv4"
}

resource "azurerm_network_interface" "provider_nic" {
  name                = "${var.prefix_name}-provider-nic"
  location            = azurerm_resource_group.provider.location
  resource_group_name = azurerm_resource_group.provider.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_provider.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.provider_pip.id
  }
}

# VIRTUAL MACHINE FOR PROVIDER
resource "azurerm_subnet" "subnet_provider" {
  name                            = "${var.prefix_name}-provider-subnet"
  resource_group_name             = azurerm_resource_group.provider.name
  virtual_network_name            = azurerm_virtual_network.provider.name
  address_prefixes                = ["192.168.1.0/24"]
  default_outbound_access_enabled = true
}

resource "azurerm_linux_virtual_machine" "provider" {
  name                            = "${var.prefix_name}-provider-vm"
  resource_group_name             = azurerm_resource_group.provider.name
  location                        = azurerm_resource_group.provider.location
  size                            = "Standard_B2s"
  admin_username                  = "provider-user"
  network_interface_ids           = [azurerm_network_interface.provider_nic.id]
  disable_password_authentication = true

  custom_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx
              systemctl enable nginx
              systemctl start nginx

              HOSTNAME=$(hostname)
              PRIVATE_IP=$(hostname -I | awk '{print $1}')

              # Create a simple HTML file to confirm Private Link access
              cat <<HTML > /var/www/html/index.html
              <h1>Hello from Provider via Private Link!</h1>
              <p>Hostname: $HOSTNAME - IP Address: $PRIVATE_IP</p>
              HTML
    EOF
  )
  admin_ssh_key {
    username   = "provider-user"
    public_key = file("~/.ssh/provider_vm_key.pub")
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}