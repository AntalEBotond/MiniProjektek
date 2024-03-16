import java.util.Scanner;

public class StringASD {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);
        System.out.print("Írj be egy stringet: ");
        String inputString = scanner.nextLine();

        if (inputString.matches("[a-zA-Z]+")) {
            System.out.println("A string csak betüket tart..");
        } else {
            System.out.println("A stringben van szám is.");
        }
    }
}
