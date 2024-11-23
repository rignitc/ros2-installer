
#!/bin/bash
set -e

# Function to get the Ubuntu version codename
get_ubuntu_version() {
    VERSION_CODENAME=$(lsb_release -c | awk '{print $2}')
    echo $VERSION_CODENAME
}

# Check if the current OS version is supported
check_os_version() {
    VERSION=$(get_ubuntu_version)

    # Jazzy supports only Ubuntu 24.04 (Noble)
    if [[ "$VERSION" == "noble" ]]; then
        ROS_DISTRO="jazzy"
        echo "Supported OS: Ubuntu 24.04 (Noble). Proceeding with ROS 2 Jazzy setup."
    # Humble and Iron support only Ubuntu 22.04 (Jammy)
    elif [[ "$VERSION" == "jammy" ]]; then
        ROS_DISTRO="humble or iron"
        echo "Supported OS: Ubuntu 22.04 (Jammy). Proceeding with ROS 2 Humble or Iron setup."
    else
        echo "Unsupported OS version. This script supports only Ubuntu 22.04 (Jammy) or Ubuntu 24.04 (Noble)."
        exit 1
    fi
}

# Call the function to check the OS version
check_os_version

# Ensure system dependencies are met
echo "Ensuring system dependencies..."
apt-get update -y
apt-get install -y curl software-properties-common locales

# Set up locales
echo "Setting up locales..."
locale-gen en_US.UTF-8
update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

# Add the ROS 2 repository depending on the version
echo "Adding ROS 2 repository..."
curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(get_ubuntu_version) main" > /etc/apt/sources.list.d/ros2.list

# Update package lists to include the new repository
echo "Updating package lists..."
apt-get update -y


# Add the ROS 2 repository depending on the version
if [[ "$ROS_DISTRO" == "jazzy" ]]; then
    # Adding ROS 2 Jazzy repository
    echo "Adding ROS 2 Jazzy repository..."
    sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
elif [[ "$ROS_DISTRO" == "humble or iron" ]]; then
    # Adding ROS 2 Humble/Iron repository
    echo "Adding ROS 2 Humble/Iron repository..."
    sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
fi

# Update the system after adding the ROS repository
echo "Updating package lists..."
sudo apt update

# Install the relevant ROS 2 packages
if [[ "$ROS_DISTRO" == "jazzy" ]]; then
    echo "Installing ROS 2 Jazzy packages..."
    sudo apt install ros-jazzy-desktop -y
elif [[ "$ROS_DISTRO" == "humble or iron" ]]; then
    echo "Installing ROS 2 Humble/Iron packages..."
    sudo apt install ros-humble-desktop -y
    # Alternatively, use `ros-iron-desktop` if you want Iron instead of Humble
fi

# Set up the ROS 2 environment
echo "Setting up ROS 2 environment..."
source /opt/ros/${ROS_DISTRO}/setup.bash

echo "ROS 2 installation complete! You can now try some examples."

# Function to install colcon
install_colcon() {
    echo "Installing colcon and necessary dependencies..."
    sudo apt update && sudo apt install -y python3-colcon-common-extensions
    if [ $? -eq 0 ]; then
        echo "colcon and dependencies installed successfully."
    else
        echo "Failed to install colcon. Please check your system configuration and try again."
        exit 1
    fi
}

# Check if colcon is installed
if ! command -v colcon &> /dev/null; then
    echo "colcon is not installed. Proceeding with installation."
    install_colcon
else
    echo "colcon is already installed. Skipping installation."
fi

# Define default workspace and source folder names
workspace_name="ros2_ws"
src_folder="src"

# Allow customization of the workspace path
read -p "Enter the workspace name (default: $workspace_name): " custom_workspace_name
workspace_name="${custom_workspace_name:-$workspace_name}"

# Get the current directory
current_dir=$(pwd)

# Full path to the workspace
workspace_path="$current_dir/$workspace_name"

# Check if the workspace already exists
if [ -d "$workspace_path" ]; then
    echo "Workspace $workspace_name already exists at $workspace_path. Skipping creation."
else
    # Create the workspace and the src folder
    echo "Creating workspace $workspace_name at $workspace_path."
    mkdir -p "$workspace_path/$src_folder"
    if [ $? -eq 0 ]; then
        echo "Workspace and src folder created successfully."
    else
        echo "Failed to create the workspace. Please check your permissions."
        exit 1
    fi
fi

# Navigate to the workspace
cd "$workspace_path" || exit

# Initialize the workspace
echo "Initializing ROS 2 workspace with colcon..."
colcon build --packages-select none &> colcon_build.log
if [ $? -eq 0 ]; then
    echo "Workspace $workspace_name initialized successfully."
    echo "Colcon build log available at: $workspace_path/colcon_build.log"
else
    echo "Workspace initialization failed. Check the log at $workspace_path/colcon_build.log."
    exit 1
fi

# Optionally add workspace setup to .bashrc
read -p "Do you want to add the workspace setup to your ~/.bashrc? [y/N]: " add_to_bashrc
if [[ "$add_to_bashrc" =~ ^[Yy]$ ]]; then
    echo "source $workspace_path/install/setup.bash" >> ~/.bashrc
    echo "Workspace setup added to ~/.bashrc. Please run 'source ~/.bashrc' or restart your shell."
fi

# Final message
echo "ROS 2 workspace setup completed. Workspace path: $workspace_path"

